package main

import "core:slice"
import "core:strings"
import "core:strconv"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:os"
import "core:bufio"
import stbi "vendor:stb/image"

WHITE :: [4]u8 {255, 255, 255, 255}
GREY :: [4]u8 {128, 128, 128, 255}
BLACK :: [4]u8 {0, 0, 0, 255}
RED :: [4]u8 {255, 0, 0, 255}
BLUE :: [4]u8 {0, 0, 255, 255}
GREEN :: [4]u8 {0, 255, 0, 255}
YELLOW :: [4]u8 {255, 200, 0, 255}

Model::struct {
    Positions: [dynamic]linalg.Vector3f32,
    Indices: [dynamic]int
}

LoadModel::proc(filePath: string) -> (Model, os.Error) {
    model: Model

    file, error := os.open(filePath)
    if error != os.ERROR_NONE {
        fmt.printfln("Failed to open model file '%s': %v", filePath, error)
        return model, error
    }
    defer os.close(file)
    
    fileReader: bufio.Reader
    buffer: [1024]byte
    bufio.reader_init_with_buf(&fileReader, os.stream_from_handle(file), buffer[:])
    defer bufio.reader_destroy(&fileReader)


    numberOfVertices := 0
    numberOfTriangles := 0

    model.Positions = make([dynamic]linalg.Vector3f32)
    model.Indices = make([dynamic]int)
    for {
		// This will allocate a string because the line might go over the backing
		// buffer and thus need to join things together
        line, error := bufio.reader_read_string(&fileReader, '\n', context.allocator)
        if (error != os.ERROR_NONE) {
            break
        }
        defer delete(line, context.allocator)
        line = strings.trim_right(line, "\r")

        // Process line
        tokens := strings.fields(line)
        numberOfTokens := len(tokens)
        if numberOfTokens == 4 {
            type := tokens[0]
            if type == "v" {
                numberOfVertices += 1
                x, isXValid := strconv.parse_f32(tokens[1])
                y, isYValid := strconv.parse_f32(tokens[2])
                z, isZValid := strconv.parse_f32(tokens[3])
                append(&model.Positions, linalg.Vector3f32 { x, y, z })
            }
            else if type == "f" {
                numberOfTriangles += 1
                v1, _ := strconv.parse_int(strings.split(tokens[1], "/")[0])
                v2, _ := strconv.parse_int(strings.split(tokens[2], "/")[0])
                v3, _ := strconv.parse_int(strings.split(tokens[3], "/")[0])

                // Triangle vertex index starts at 1 instead of 0
                v1 -= 1
                v2 -= 1
                v3 -= 1
                append(&model.Indices, v1)
                append(&model.Indices, v2)
                append(&model.Indices, v3)
            }
            //fmt.printf("Formatted: %s >> %s", tokens[0], line)
        }
        else {
            //fmt.printf("No format: %s", line)
        }
    }

    fmt.printf("V: %d, F: %d", len(model.Positions), len(model.Indices) / 3)

    return model, os.ERROR_NONE
}

ReleaseModel::proc(model: Model) {
    delete(model.Positions)
    delete(model.Indices)
}

Image::struct {
    Pixels: []u8,
    Width, Height: int
}

CreateImage::proc(width: int, height: int) -> Image {
    return Image {
        Pixels = make([]u8, width * height * 4), 
        Width = width,
        Height = height
    }
}

FreeImage::proc(image: ^Image) {
    delete(image.Pixels)
    image.Width = 0
    image.Height = 0
}

MakeImageMonoColor::proc(image: Image, color: [4]u8) {
    for i := 0; i < image.Width * image.Height; i += 1 {
        pixelIndex := i*4
        image.Pixels[pixelIndex+0] = color[0]
        image.Pixels[pixelIndex+1] = color[1]
        image.Pixels[pixelIndex+2] = color[2]
        image.Pixels[pixelIndex+3] = color[3]
    }
}

SetColor::proc(image: Image, color: [4]u8, x, y: int) {
    pixelIndex := ((image.Height - y) * image.Width + x) * 4
    if (pixelIndex >= len(image.Pixels)) {
        return
    }

    image.Pixels[pixelIndex+0] = color[0]
    image.Pixels[pixelIndex+1] = color[1]
    image.Pixels[pixelIndex+2] = color[2]
    image.Pixels[pixelIndex+3] = color[3]
}

Line::proc(image: Image, color: [4]u8, ax, ay, bx, by: int) {
    // Make them mutable
    ax := ax
    bx := bx
    ay := ay
    by := by

    isTooSteep: bool = math.abs(ax - bx) < math.abs(ay - by)
    if (isTooSteep) {
        ax, ay = ay, ax
        bx, by = by, bx
    }

    if (ax > bx) {
        // Swap the points so the for-loop still runs through the x range
        ax, bx = bx, ax
        ay, by = by, ay
    }
    
    width := bx - ax;
    height := by - ay;
    derror := math.abs(height) * 2; // (height / width) * width * 2 => height * 2

    error: f64 = 0;
    y := ay;
    if isTooSteep {
        for x := ax; x <= bx; x += 1
        {
            SetColor(image, color, cast(int) y, cast(int) x)
            error += f64(derror);
            if (error > f64(width))  // 0.5 * width * 2 => width
            {
                y += (by > ay) ? 1 : -1;
                error -= f64(width * 2); // 1.0 * width * 2 => width * 2
            }
        }
    } 
    else {
        for x := ax; x <= bx; x += 1
        {
            SetColor(image, color, cast(int) x, cast(int) y)
            error += f64(derror);
            if (error > f64(width))  // 0.5 * width * 2 => width
            {
                y += (by > ay) ? 1 : -1;
                error -= f64(width * 2); // 1.0 * width * 2 => width * 2
            }
        }
    }
}

Triangle::proc(image: Image, color: [4]u8, ax, ay, bx, by, cx, cy: int) {
    ax := ax
    ay := ay
    bx := bx
    by := by
    cx := cx
    cy := cy
    
    // Sort the vertcies in ascending (a is the lowest, c is the highest)
    if ay > by {  
        ax, bx = bx, ax
        ay, by = by, ay
    }
    if ay > cy {
        ax, cx = cx, ax
        ay, cy = cy, ay
    }
    if by > cy {
        bx, cx = cx, bx
        by, cy = cy, by
    }

    for y in ay..=by {
        x0 := getXOnLineFromY(ax, ay, cx, cy, y)
        x1 := getXOnLineFromY(ax, ay, bx, by, y)
        if x0 > x1 {
            x0, x1 = x1, x0
        }
        for x in x0..=x1 {
            SetColor(image, color, x, y)
        }
    }

    for y in by..=cy {
        x0 := getXOnLineFromY(ax, ay, cx, cy, y)
        x1 := getXOnLineFromY(bx, by, cx, cy, y)
        if x0 > x1 {
            x0, x1 = x1, x0
        }
        for x in x0..=x1 {
            SetColor(image, color, x, y)
        }
    }

    getXOnLineFromY::proc(point1X, point1Y, point2X, point2Y, targetY: int) -> int {
        return point1X + cast(int) math.round(f64(targetY - point1Y) * f64(point2X - point1X) / f64(point2Y - point1Y))
    }
}

DrawModelWireframe::proc(image: Image, model: Model, color: [4]u8) {

    for i := 0; i < len(model.Indices); i += 3 {
        v1 := transformCoordinate(model.Positions[model.Indices[i]], image)
        v2 := transformCoordinate(model.Positions[model.Indices[i + 1]], image)
        v3 := transformCoordinate(model.Positions[model.Indices[i + 2]], image)
        
        // Draw face edges
        Line(image, color, v1[0], v1[1], v2[0], v2[1])
        Line(image, color, v2[0], v2[1], v3[0], v3[1])
        Line(image, color, v3[0], v3[1], v1[0], v1[1])

        // Also draw white dots at the vertices
        SetColor(image, WHITE, v1[0], v1[1])
        SetColor(image, WHITE, v2[0], v2[1])
        SetColor(image, WHITE, v3[0], v3[1])
    }

    transformCoordinate::proc(point: linalg.Vector3f32, image: Image) -> [2]int {
        return [2]int { cast(int) math.round((point.x + 1) * f32(image.Width) / 2), cast(int) math.round((point.y + 1) * f32(image.Height) / 2) }
    }
}

main::proc() {
    // Triangle drawing
    {
        image: Image = CreateImage(128, 128);
        defer FreeImage(&image);
        MakeImageMonoColor(image, BLACK)
        Triangle(image, RED, 7, 45, 35, 100, 45, 60);
        Triangle(image, WHITE, 120, 35, 90, 5, 45, 110);
        Triangle(image, GREEN, 115, 83, 80, 90, 85, 120);
        stbi.write_png("output_image.png", i32(image.Width), i32(image.Height), 4, raw_data(image.Pixels), i32(image.Width) * 4)
    }

    // Model wireframe (WIP)
    {
        image: Image = CreateImage(800, 800);
        defer FreeImage(&image);
        MakeImageMonoColor(image, BLACK)

        model, error := LoadModel("diablo3_pose.obj")
        defer ReleaseModel(model)
        DrawModelWireframe(image, model, RED)

        stbi.write_png("diablo_wireframe.png", i32(image.Width), i32(image.Height), 4, raw_data(image.Pixels), i32(image.Width) * 4)
    }
}