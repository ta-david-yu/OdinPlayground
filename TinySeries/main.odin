package main

import math "core:math"
import stbi "vendor:stb/image"

WHITE :: [4]u8 {255, 255, 255, 255}
BLACK :: [4]u8 {0, 0, 0, 255}
RED :: [4]u8 {255, 0, 0, 255}
BLUE :: [4]u8 {0, 0, 255, 255}
GREEN :: [4]u8 {0, 255, 0, 255}
YELLOW :: [4]u8 {255, 200, 0, 255}

Image::struct {
    Pixels: []u8,
    Width, Height: int
}

AllocateImage::proc(width: int, height: int) -> Image {
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
    image: Image = AllocateImage(64, 64);
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

    //stbi.flip_vertically_on_write(true)
	stbi.write_png("output_image.png", i32(image.Width), i32(image.Height), 4, raw_data(image.Pixels), i32(image.Width) * 4)
}