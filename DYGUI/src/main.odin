package main

import "core:strings"
import "base:runtime"
import "core:c"
import "core:fmt"
import "vendor:sdl3"
import "vendor:sdl3/ttf"

import dygui "dygui"

movingButtonPos : [2]f32 = { 50, 100 }
movingSpeed : f32 = 50

fonts : [dynamic]^ttf.Font

measureText :: proc(textContent: string, fontConfig: dygui.FontConfig) -> dygui.Dimensions 
{
	font := fonts[fontConfig.FontId]
	currentFontSize := ttf.GetFontSize(font)
	targetMeasureFontSize := cast(f32) fontConfig.FontSize

	needToChangeFontSize : bool = currentFontSize != targetMeasureFontSize
	if (needToChangeFontSize)
	{
		if (!ttf.SetFontSize(font, targetMeasureFontSize))
		{
			// TODO: error handling
		}
	}

	measuredTextWidth, measuredTextHeight : c.int = 0, 0
	textContentInCStr := strings.clone_to_cstring(textContent, context.temp_allocator)
	getSizeResult := ttf.GetStringSize(font, textContentInCStr, 0, &measuredTextWidth, &measuredTextHeight)

	if (needToChangeFontSize)
	{
		if (!ttf.SetFontSize(font, currentFontSize))
		{
			// TODO: error handling
		}
	}

	return { cast(f32) measuredTextWidth, cast(f32) measuredTextHeight }
}

main :: proc() 
{
	typeId := typeid_of(dygui.Rect)
	info := type_info_of(typeId)


	timeLastFrame : u64 = 0
	time : u64 = 0

	if (!sdl3.SetAppMetadata("DYGUI", "0.1.0", "com.ta-david-ui.dygui")) 
	{
		sdl3.Log("Failed to set metadata")
	}

	if (!sdl3.Init(sdl3.INIT_VIDEO)) 
	{
		sdl3.Log("Couldn't initialize SDL")
		return
	}
	defer sdl3.Quit()

	ttfResult := ttf.Init()
	if (!ttfResult) 
	{
		sdl3.Log("Couldn't initialize ttf")
		return
	}

	// Load different fonts
	latinFont : ^ttf.Font = ttf.OpenFont("fonts/m6x11plus.ttf", 36)
	if (latinFont == nil)
	{
		sdl3.Log("Failed to load ttf font file")
		return
	}
	defer ttf.CloseFont(latinFont)
	append(&fonts, latinFont)
	
	chineseFont : ^ttf.Font = ttf.OpenFont("fonts/Cubic_11.ttf", 33)
	if (chineseFont == nil)
	{
		sdl3.Log("Failed to load ttf font file")
		return
	}
	defer ttf.CloseFont(chineseFont)
	append(&fonts, chineseFont)

	window : ^sdl3.Window = sdl3.CreateWindow("DYGUI", 640, 480, sdl3.WINDOW_RESIZABLE)
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
	dygui.SetMeasureTextFunction(measureText)
	dygui.SetMainFontConfig({ FontId = 0, FontSize = 18 })

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
			if (dygui.ColorButton("Red", {10, 10}, {40, 20}, {255, 0, 0, 255})) 
			{
				fmt.println("Click Red")
			}

			if (dygui.ColorButton("Green", {200, 150}, {40, 20}, {0, 255, 0, 255})) 
			{
				fmt.println("Click Green1")
			}

			if (dygui.ColorButton("Green", {150, 350}, {40, 20}, {0, 255, 0, 255})) 
			{
				fmt.println("Click Green2")
			}
			
			deltaTime : f32 = cast(f32) (time - timeLastFrame) / 1000.0
			
			width : f32 = 40
			movingButtonPos.x += deltaTime * movingSpeed
			if (movingButtonPos.x > 640)
			{
				movingButtonPos.x = -width
			}

			if (dygui.ColorButton("Moving", movingButtonPos, {width, 20}, {0, 0, 255, 255})) 
			{
				fmt.println("Click Moving")
			}
			if (dygui.IsItemHovered())
			{
				movingSpeed = 100
			}
			else 
			{
				movingSpeed = 200
			}

			if (dygui.Button("Test Button", { 255, 255, 255, 255 }, { 300, 250 }))
			{
				fmt.println("Test Button with Text Pressed")
			}

			dygui.PushFontConfig({ FontId = 1, FontSize = 22 }) // Font Id 1 is for chinese.
			
			if (dygui.Button("中文按鈕", { 255, 255, 255, 255 }, { 400, 300 }))
			{
				fmt.println("Big Button with Text Pressed")
			}
			dygui.PopFontConfig()
		}
		dygui.EndFrame()

		// Render
		sdl3.SetRenderDrawColor(renderer, 0, 0, 0, sdl3.ALPHA_OPAQUE)
		sdl3.RenderClear(renderer)

		frame := &dygui.GetState().Frame
		for i := 0; i < frame.NumberOfDrawCommands; i += 1 
		{
			drawCommand := frame.DrawCommands[i]
			switch drawData in drawCommand.Data
			{
				case dygui.RectangleDrawData:
					sdl3.SetRenderDrawColor(renderer, drawData.Color.r, drawData.Color.g, drawData.Color.b, sdl3.ALPHA_OPAQUE)
					rect := sdl3.FRect {}
					rect.x, rect.y = drawData.Rect.Position.x, drawData.Rect.Position.y
					rect.w, rect.h = drawData.Rect.Size.x, drawData.Rect.Size.y
					sdl3.RenderFillRect(renderer, &rect)
				case dygui.TextDrawData:
					font := fonts[drawData.FontConfig.FontId]
					currentFontSize := ttf.GetFontSize(font)
					targetMeasureFontSize := cast(f32) drawData.FontConfig.FontSize
					needToChangeFontSize : bool = currentFontSize != targetMeasureFontSize
					if (needToChangeFontSize)
					{
						if (!ttf.SetFontSize(font, targetMeasureFontSize))
						{
							// TODO: error handling
						}
					}
					textContentInCStr := strings.clone_to_cstring(drawData.TextContent, context.temp_allocator)
					textSurface : ^sdl3.Surface = ttf.RenderText_Blended(font, textContentInCStr, 0, drawData.TextColor.rgba)
					defer sdl3.DestroySurface(textSurface)
					
					textTexture : ^sdl3.Texture = sdl3.CreateTextureFromSurface(renderer, textSurface)
					defer sdl3.DestroyTexture(textTexture)

					textRect := sdl3.FRect { x=drawData.TextRect.Position.x, y=drawData.TextRect.Position.y, w=drawData.TextRect.Size.x, h=drawData.TextRect.Size.y }
					sdl3.RenderTexture(renderer, textTexture, nil, &textRect)
			}
		}

		sdl3.RenderPresent(renderer)

		timeLastFrame = time
		time = sdl3.GetTicks()

		free_all(context.temp_allocator)
	}
}