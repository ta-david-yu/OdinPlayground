package main

import "core:fmt"
import "vendor:raylib"

RaylibRenderingLoop::proc() {
	width  := i32(800)
	height := i32(800)
	raylib.InitWindow(width, height, "Tiny Renderer")
	defer raylib.CloseWindow()

	raylib.SetTargetFPS(60)

	pause: bool
	for !raylib.WindowShouldClose() {
		if raylib.IsKeyPressed(.P) {
			pause = !pause
		}

		raylib.BeginDrawing()
        {
            raylib.ClearBackground(raylib.DARKGRAY)
            message :: "Hello Box2D!"
            raylib.DrawText("Congrats! You created your first window!", 190, 200, 20, raylib.LIGHTGRAY);
        }
        raylib.EndDrawing()
	}
}