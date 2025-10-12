package main

import "vendor:sdl3"

main :: proc() {
	if (!sdl3.SetAppMetadata("DYGUI", "0.1.0", "com.ta-david-ui.dygui")) {
		sdl3.Log("Failed to set metadata");
	}

	if (!sdl3.Init(sdl3.INIT_VIDEO)) {
		sdl3.Log("Couldn't initialize SDL")
		return
	}
	defer sdl3.Quit()

	window : ^sdl3.Window = sdl3.CreateWindow("DYGUI", 640, 480, sdl3.WINDOW_RESIZABLE);
	if (window == nil) {
		sdl3.Log(sdl3.GetError())
	}
	defer sdl3.DestroyWindow(window)

	driverName : cstring = ""
	renderer : ^sdl3.Renderer = sdl3.CreateRenderer(window, driverName);
	if (renderer == nil) {
		sdl3.Log(sdl3.GetError())
	}

	sdl3.SetRenderLogicalPresentation(renderer, 640, 480, sdl3.RendererLogicalPresentation.LETTERBOX)

	for {
		// Event
		event: sdl3.Event
		for sdl3.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				return
			}
		}

		// Render
		sdl3.SetRenderDrawColor(renderer, 33, 33, 33, sdl3.ALPHA_OPAQUE)
		sdl3.RenderClear(renderer)

		rect : sdl3.FRect = sdl3.FRect {}
		rect.x, rect.y = 100, 100
		rect.w, rect.h = 440, 280

		sdl3.SetRenderDrawColor(renderer, 0, 0, 255, sdl3.ALPHA_OPAQUE)
		sdl3.RenderFillRect(renderer, &rect)

		sdl3.RenderPresent(renderer)
	}
}
