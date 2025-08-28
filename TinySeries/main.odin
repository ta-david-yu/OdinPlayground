package main

import stbi "vendor:stb/image"

WHITE :: [4]u8 {255, 255, 255, 255}
RED :: [4]u8 {255, 0, 0, 255}
BLUE :: [4]u8 {0, 0, 255, 255}

Image::struct {
    Pixels: []u8,
    Width, Height: int
}

AllocateImage::proc(width: int = 512, height: int = 512) -> Image {
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
    pixelIndex := (y * image.Width + x) * 4
    image.Pixels[pixelIndex+0] = color[0]
    image.Pixels[pixelIndex+1] = color[1]
    image.Pixels[pixelIndex+2] = color[2]
    image.Pixels[pixelIndex+3] = color[3]
}

main::proc() {
    image: Image = AllocateImage(512, 512);
    defer FreeImage(&image);
    
    MakeImageMonoColor(image, RED)

    for i in 0..<512 {
        SetColor(image, BLUE, i, i)
    }

	stbi.write_png("output_image.png", i32(image.Width), i32(image.Height), 4, raw_data(image.Pixels), i32(image.Width) * 4)
}