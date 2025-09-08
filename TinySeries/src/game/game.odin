package game

import "core:math"
import "core:strconv"
import "core:strings"
import "core:bufio"
import "core:os"
import "core:math/linalg"
import "core:c"
import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"
import stbi "vendor:stb/image"

GameMemory::struct {
    ShouldQuit: bool,
    Framebuffer: Image,
    Depthbuffer: Image,
    Model: Model,
    Transform: Transform,

    RenderTexture: rl.Texture2D,
    DepthRenderTexture: rl.Texture2D,
}

g_Memory: ^GameMemory

MODEL_NAME :: "diablo3_pose"

@(export)
Game_Init::proc() {
    rl.InitWindow(1600, 800, "Odin Tiny Series")
    rl.SetTargetFPS(60)

    g_Memory = new (GameMemory)
    g_Memory.Framebuffer = CreateImage(800, 800)
    g_Memory.Depthbuffer = CreateImage(800, 800)
    MakeImageMonoColor(g_Memory.Depthbuffer, BLACK)

    modelFile: string = fmt.tprintf("assets/%s.obj", MODEL_NAME)
    model, error := LoadModel(modelFile)
    g_Memory.Model = model

    g_Memory.Transform = {
        Position = {0, 0, 0},
        Rotation = {0, 0, 0},
        Scale = {1, 1, 1}
    }
}

@(export)
Game_RequireReset::proc() -> bool {
    return false    
}

/* Return false if the game should be shutdown */
@(export)
Game_Update::proc() -> bool {
	if rl.IsKeyPressed(.ESCAPE) {
		g_Memory.ShouldQuit = true
	}
    if rl.IsKeyPressed(.R) {
        RenderImages()
    }
    rl.BeginDrawing()
    {
        deltaTime := rl.GetFrameTime()
	    rl.ClearBackground(rl.BLACK)
        rl.DrawTexture(g_Memory.RenderTexture, 0, 0, { 255, 255, 255, 255 })
        rl.DrawTexture(g_Memory.DepthRenderTexture, 800, 0, { 255, 255, 255, 255 })
        rl.DrawText("PRESS R TO RENDER IMAGE", 20, 20, 12, {255, 255, 255, 255})
    }
    rl.EndDrawing()

    keepRunning: bool = !g_Memory.ShouldQuit && !rl.WindowShouldClose() 
    return keepRunning
}

@(export)
Game_Shutdown::proc() {
    FreeImage(&g_Memory.Framebuffer)
    FreeImage(&g_Memory.Depthbuffer)
    free(g_Memory)
    rl.CloseWindow()
}

@(export)
Game_GetMemory::proc() -> rawptr {
    return g_Memory
}

/*  
Call this function after the game dll is reloaded.
You should pass in the pointer to the original game memory.
*/
@(export)
Game_OnHotReloaded::proc(gameMemory: ^GameMemory) {
    g_Memory = gameMemory
    RenderImages()
}


BLACK :: [4]u8 {0, 0, 0, 255}
Model::struct {
    Positions: [dynamic]linalg.Vector3f32,
    Indices: [dynamic]int
}

RenderImages::proc() {
    ReleaseModel(g_Memory.Model)
    modelFile: string = fmt.tprintf("assets/%s.obj", MODEL_NAME)
    model, error := LoadModel(modelFile)
    g_Memory.Model = model

    // Re-render the model to the image
    MakeImageMonoColor(g_Memory.Framebuffer, BLACK)
    MakeImageMonoColor(g_Memory.Depthbuffer, BLACK)
    DrawModel(g_Memory.Framebuffer, g_Memory.Depthbuffer, g_Memory.Model)

    outputImageFile: string = fmt.tprintf("%s.png", MODEL_NAME)
    stbi.write_png(
        strings.unsafe_string_to_cstring(outputImageFile), 
        i32(g_Memory.Framebuffer.Width), 
        i32(g_Memory.Framebuffer.Height), 
        4, 
        raw_data(g_Memory.Framebuffer.Pixels), 
        i32(g_Memory.Framebuffer.Width) * 4
    )

    // Load the image as a texture again and render it
    if (rl.IsTextureValid(g_Memory.RenderTexture)) {
        // Unload the old one first
        rl.UnloadTexture(g_Memory.RenderTexture)
    }
    g_Memory.RenderTexture = rl.LoadTexture(strings.unsafe_string_to_cstring(outputImageFile))

    // Also load the depth buffer for debugging
    depthBufferImageFile: string = fmt.tprintf("depthBuffer.png")
    if (rl.IsTextureValid(g_Memory.DepthRenderTexture)) {
        // Unload the old one first
        rl.UnloadTexture(g_Memory.DepthRenderTexture)
    }
    g_Memory.DepthRenderTexture = rl.LoadTexture(strings.unsafe_string_to_cstring(depthBufferImageFile))
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

GetColor::proc(image: Image, point: [2]int) -> [4]u8 {
    pixelIndex := ((image.Height - point.y) * image.Width + point.x) * 4
    if (pixelIndex >= len(image.Pixels)) {
        return { 0, 0, 0, 0 }
    }

    return image.Pixels[pixelIndex]
}

TriangleWithZTest::proc(image: Image, depthBuffer: Image, color: [4]u8, a, b, c: [3]int) {
    minX := math.min(a.x, b.x)
    minX = math.min(minX, c.x)
    minY := math.min(a.y, b.y)
    minY = math.min(minY, c.y)

    maxX := math.max(a.x, b.x)
    maxX = math.max(maxX, c.x)
    maxY := math.max(a.y, b.y)
    maxY = math.max(maxY, c.y)

    totalArea := SignedTriangleArea(cast(f32) a.x, cast(f32) a.y, cast(f32) b.x, cast(f32) b.y, cast(f32) c.x, cast(f32) c.y)
    if (totalArea < 1) {
        // If the triangle covers less than one pixel (area<1) we will discard it.
        // If the signed area is negative, it means the triangle is facing backward and we will discard it as well.
        return
    }

    for x := minX; x <= maxX; x += 1 {
        for y := minY; y <= maxY; y += 1 {
            // Here we want to use barycentric coordinate to determine if the pixel is inside the triangle.
            // -> P = aA + bB + cC
            // a, b, and c are proportional to the sub-triangle areas: Area(PBC), Area(PCA), and Area(PAB) 
            // Therefore if any sub-triangle has a negative value, then the pixel is outside the triangle.
            alpha := SignedTriangleArea(cast(f32) x, cast(f32) y, cast(f32) b.x, cast(f32) b.y, cast(f32) c.x, cast(f32) c.y) / totalArea
            beta := SignedTriangleArea(cast(f32) x, cast(f32) y, cast(f32) c.x, cast(f32) c.y, cast(f32) a.x, cast(f32) a.y) / totalArea
            gamma := SignedTriangleArea(cast(f32) x, cast(f32) y, cast(f32) a.x, cast(f32) a.y, cast(f32) b.x, cast(f32) b.y) / totalArea
            if (alpha < 0 || beta < 0 || gamma < 0) {
                // Discard the pixel since it's outside the triangle
                continue
            }

            z : u8 = u8((cast(f32) a.z * alpha) + (cast(f32) b.z * beta) + (cast(f32) c.z * gamma))
            if z < GetColor(depthBuffer, { x, y })[0] {
                continue
            }
            
            SetColor(depthBuffer, { z, z, z, 255 }, x, y)
            SetColor(image, color, x, y)
        }
    }
}

DrawModel::proc(image: Image, depthBuffer: Image, model: Model) {
    for i := 0; i < len(model.Indices); i += 3 {
        v1 := transformCoordinate(model.Positions[model.Indices[i]], image)
        v2 := transformCoordinate(model.Positions[model.Indices[i + 1]], image)
        v3 := transformCoordinate(model.Positions[model.Indices[i + 2]], image)
        
        color : [4]u8 = { cast(u8) rand.int_max(256), cast(u8) rand.int_max(256), cast(u8) rand.int_max(256), 255 }
        TriangleWithZTest(image, depthBuffer, color, v1, v2, v3)
    }

    stbi.write_png("depthBuffer.png", i32(depthBuffer.Width), i32(depthBuffer.Height), 4, raw_data(depthBuffer.Pixels), i32(depthBuffer.Width) * 4)

    transformCoordinate::proc(point: linalg.Vector3f32, image: Image) -> [3]int {
        return [3]int { 
            cast(int) math.round((point.x + 1) * f32(image.Width) / 2), 
            cast(int) math.round((point.y + 1) * f32(image.Height) / 2),
            cast(int) (f32(point.z + 1) * 127.5)
        }
    }
}

SignedTriangleArea::proc(ax, ay, bx, by, cx, cy: f32) -> f32 {
    return 0.5 * ((by - ay) * (bx + ax) +
                  (cy - by) * (cx + bx) +
                  (ay - cy) * (ax + cx))
}