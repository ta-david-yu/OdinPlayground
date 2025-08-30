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
    
    y := f64(ay)
    yOffset := f64(by - ay) / f64(bx - ax);
    for x := ax; x <= bx; x += 1 {
        if (isTooSteep) {
            SetColor(image, color, cast(int) y, cast(int) x)
        } else {
            SetColor(image, color, cast(int) x, cast(int) y)
        }

        y += yOffset;
    }
}

main::proc() {
    // Line drawing
    {
        image: Image = CreateImage(64, 64);
        defer FreeImage(&image);
        MakeImageMonoColor(image, BLACK)
        ax, ay := 7, 3;
        bx, by :=12,37;
        cx, cy :=62,53;
        Line(image, BLUE, ax, ay, bx, by)
        Line(image, GREEN, cx, cy, bx, by)
        Line(image, YELLOW, cx, cy, ax, ay)
        Line(image, RED, ax, ay, cx, cy)
        SetColor(image, WHITE, ax, ay)
        SetColor(image, WHITE, bx, by)
        SetColor(image, WHITE, cx, cy)
        stbi.write_png("output_image.png", i32(image.Width), i32(image.Height), 4, raw_data(image.Pixels), i32(image.Width) * 4)
    }

    // Model wireframe (WIP)
    {
        model, error := LoadModel("diablo3_pose.obj")
        defer ReleaseModel(model)
    }
}