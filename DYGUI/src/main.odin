package main

import "core:fmt"
import dygui "dygui"
import "vendor:sdl3"

main :: proc() 
{
	if (!sdl3.SetAppMetadata("DYGUI", "0.1.0", "com.ta-david-ui.dygui")) 
	{
		sdl3.Log("Failed to set metadata");
	}

	if (!sdl3.Init(sdl3.INIT_VIDEO)) 
	{
		sdl3.Log("Couldn't initialize SDL")
		return
	}
	defer sdl3.Quit()

	window : ^sdl3.Window = sdl3.CreateWindow("DYGUI", 640, 480, sdl3.WINDOW_RESIZABLE);
	if (window == nil)
	{
		sdl3.Log(sdl3.GetError())
	}
	defer sdl3.DestroyWindow(window)

	driverName : cstring = ""
	renderer : ^sdl3.Renderer = sdl3.CreateRenderer(window, driverName);
	if (renderer == nil) 
	{
		sdl3.Log(sdl3.GetError())
	}

	sdl3.SetRenderLogicalPresentation(renderer, 640, 480, sdl3.RendererLogicalPresentation.LETTERBOX)

	x, y : f32 = 100, 100

	
	dygui.Init(dygui.Canvas{Width=640, Height=480})

	for 
	{
		// Event
		event: sdl3.Event
		for sdl3.PollEvent(&event) 
		{
			#partial switch event.type 
			{
				case .QUIT:
					return
				case .MOUSE_MOTION:
					x = event.button.x
					y = event.button.y
					dygui.GetInputState().MousePosition = { x, y }
					break
				case .MOUSE_BUTTON_DOWN:
					dygui.GetInputState().MouseButtons[event.button.button - 1] = true
					break
				case .MOUSE_BUTTON_UP:
					dygui.GetInputState().MouseButtons[event.button.button - 1] = false
					break
			}
		}

		// DYGUI
		dygui.NewFrame()
		{
			if (dygui.Button("Red", {10, 10}, {40, 20}, {255, 0, 0, 255})) 
			{
				fmt.println("Red")
			}

			if (dygui.Button("Green", {200, 150}, {40, 20}, {0, 255, 0, 255})) 
			{
				fmt.println("Green")
			}
		}
		dygui.EndFrame()

		// Render
		sdl3.SetRenderDrawColor(renderer, 0, 0, 0, sdl3.ALPHA_OPAQUE)
		sdl3.RenderClear(renderer)

		frame := &dygui.GetState().Frame
		for i := 0; i < frame.NumberOfButtons; i += 1 
		{
			button := frame.Buttons[i];
			sdl3.SetRenderDrawColor(renderer, button.Color.r, button.Color.g, button.Color.b, sdl3.ALPHA_OPAQUE)
			rect : sdl3.FRect = sdl3.FRect {}
			rect.x, rect.y = button.Rect.Position.x, button.Rect.Position.y
			rect.w, rect.h = button.Rect.Size.x, button.Rect.Size.y
			sdl3.RenderFillRect(renderer, &rect)
		}

		/*
		rect : sdl3.FRect = sdl3.FRect {}
		rect.x, rect.y = x, y
		rect.w, rect.h = 50, 50

		sdl3.SetRenderDrawColor(renderer, 0, 0, 255, sdl3.ALPHA_OPAQUE)
		sdl3.RenderFillRect(renderer, &rect)*/

		sdl3.RenderPresent(renderer)
	}
}
