package dye

import "base:runtime"
import "core:c"
import "core:math"
import "core:strings"

import "vendor:sdl3"
import "vendor:sdl3/ttf"

import dygui "gui"

WindowSettings :: struct {
	Name:   cstring,
	Width:  c.int,
	Height: c.int,
}

EngineEventFunctions :: struct {
	OnUpdate: proc(deltaTime: f32),
	OnImGui:  proc(deltaTime: f32),
	OnRender: proc(deltaTime: f32),
}

EngineMemory :: struct {
	MainWindowSettings: WindowSettings,
	MainWindow:         ^sdl3.Window,
	MainRenderer:       ^sdl3.Renderer,
	GUIContext:         ^dygui.GUIContext,
	Fonts:              [dynamic]^ttf.Font,
	TextEngine:         ^ttf.TextEngine,
	Ticks:              u64,
	TicksLastUpdate:    u64,
}

SetAppMetadata :: proc(appName, appVersion, appIdentifier: cstring) -> bool {
	return sdl3.SetAppMetadata(appName, appVersion, appIdentifier)
}

AllocateEngine :: proc() -> ^EngineMemory {
	return new(EngineMemory)
}

InitEngineSystems :: proc(engineMemory: ^EngineMemory) -> bool {
	if (!sdl3.Init(sdl3.INIT_VIDEO)) {
		sdl3.Log("Couldn't initialize SDL3")
		sdl3.Log(sdl3.GetError())
		return false
	}

	windowSettings := engineMemory.MainWindowSettings
	engineMemory.MainWindow = sdl3.CreateWindow(
		windowSettings.Name,
		windowSettings.Width,
		windowSettings.Height,
		sdl3.WINDOW_RESIZABLE,
	)
	if engineMemory.MainWindow == nil {
		sdl3.Log(sdl3.GetError())
		return false
	}

	rendererDriverName: cstring = ""
	engineMemory.MainRenderer = sdl3.CreateRenderer(engineMemory.MainWindow, rendererDriverName)
	if (engineMemory.MainRenderer == nil) {
		sdl3.Log(sdl3.GetError())
		return false
	}
	sdl3.SetRenderLogicalPresentation(
		engineMemory.MainRenderer,
		windowSettings.Width,
		windowSettings.Height,
		sdl3.RendererLogicalPresentation.LETTERBOX,
	)

	if (!ttf.Init()) {
		sdl3.Log("Couldn't initialize ttf")
		return false
	}

	engineMemory.TextEngine = ttf.CreateRendererTextEngine(engineMemory.MainRenderer)
	if (engineMemory.TextEngine == nil) {
		sdl3.Log(sdl3.GetError())
		return false
	}

	engineMemory.GUIContext = dygui.CreateContext()
	engineMemory.GUIContext.Canvas = {
		Width  = cast(f32)engineMemory.MainWindowSettings.Width,
		Height = cast(f32)engineMemory.MainWindowSettings.Height,
	}

	dygui.SetContextAsGlobal(engineMemory.GUIContext)
	dygui.SetMeasureTextFunction(measureText, engineMemory)

	return true
}

OnHotReload :: proc(engineMemory: ^EngineMemory) {
	dygui.SetContextAsGlobal(engineMemory.GUIContext)
	dygui.SetMeasureTextFunction(measureText, engineMemory)
}

OnEngineUpdate :: proc(engineMemory: ^EngineMemory, eventFunctions: EngineEventFunctions) {
	deltaTimeInMiliseconds := engineMemory.Ticks - engineMemory.TicksLastUpdate
	deltaTimeInSeconds: f32 = cast(f32)deltaTimeInMiliseconds * 0.001

	// Poll and process system event
	event: sdl3.Event
	for sdl3.PollEvent(&event) {
		#partial switch event.type {
		case .QUIT:
			return
		case .MOUSE_MOTION:
			x := event.button.x
			y := event.button.y

			rendererRect: sdl3.FRect
			if sdl3.GetRenderLogicalPresentationRect(engineMemory.MainRenderer, &rendererRect) {
				x -= rendererRect.x
				y -= rendererRect.y

				guiContext := dygui.GetGUIContext()
				x *= guiContext.Canvas.Width / rendererRect.w
				y *= guiContext.Canvas.Height / rendererRect.h
			}
			dygui.GetInputState().MousePosition = {x, y}
			break
		case .MOUSE_BUTTON_DOWN:
			dygui.GetInputState().MouseButtons[event.button.button - 1] = true
			break
		case .MOUSE_BUTTON_UP:
			dygui.GetInputState().MouseButtons[event.button.button - 1] = false
			break
		}
	}

	// Event: OnUpdate
	eventFunctions.OnUpdate(deltaTimeInSeconds)

	// GUI
	dygui.NewFrame()
	{
		// Event: OnImGui
		eventFunctions.OnImGui(deltaTimeInSeconds)
	}
	dygui.EndFrame()

	// Render
	{
		// Clear
		sdl3.SetRenderDrawColor(engineMemory.MainRenderer, 180, 180, 180, sdl3.ALPHA_OPAQUE)
		sdl3.RenderClear(engineMemory.MainRenderer)

		// Event: OnRender
		eventFunctions.OnRender(deltaTimeInSeconds)
		renderImGuiCommands(engineMemory)

		// Present
		sdl3.RenderPresent(engineMemory.MainRenderer)
	}

	// Tick
	engineMemory.TicksLastUpdate = engineMemory.Ticks
	engineMemory.Ticks = sdl3.GetTicks()

	// Release memory in the temp allocator at the end of the frame
	free_all(context.temp_allocator)
}

@(private)
renderImGuiCommands :: proc(engineMemory: ^EngineMemory) {
	renderer := engineMemory.MainRenderer
	fonts := engineMemory.Fonts
	textEngine := engineMemory.TextEngine

	frame := &dygui.GetState().Frame
	for i := 0; i < frame.NumberOfDrawCommands; i += 1 {
		drawCommand := frame.DrawCommands[i]
		switch drawData in drawCommand.Data
		{
		case dygui.FilledRectangleDrawData:
			sdl3.SetRenderDrawBlendMode(renderer, sdl3.BLENDMODE_BLEND)
			sdl3.SetRenderDrawColor(
				renderer,
				drawData.Color.r,
				drawData.Color.g,
				drawData.Color.b,
				drawData.Color.a,
			)

			hasRoundedCorners: bool =
				drawData.CornerRadius.TL > 0 ||
				drawData.CornerRadius.TR > 0 ||
				drawData.CornerRadius.BR > 0 ||
				drawData.CornerRadius.BL > 0
			if (hasRoundedCorners) {
				drawFilledRoundedRect(
					renderer,
					drawData.Rect,
					drawData.CornerRadius,
					drawData.Color,
				)
			} else {
				rect := sdl3.FRect{}
				rect.x, rect.y = drawData.Rect.Position.x, drawData.Rect.Position.y
				rect.w, rect.h = drawData.Rect.Size.x, drawData.Rect.Size.y
				sdl3.RenderFillRect(renderer, &rect)
			}
		case dygui.TextDrawData:
			font := fonts[drawData.FontConfig.FontId]
			currentFontSize := ttf.GetFontSize(font)
			targetMeasureFontSize := cast(f32)drawData.FontConfig.FontSize
			needToChangeFontSize: bool = currentFontSize != targetMeasureFontSize
			if (needToChangeFontSize) {
				if (!ttf.SetFontSize(font, targetMeasureFontSize)) {break}
			}
			textContentInCStr := strings.clone_to_cstring(
				drawData.TextContent,
				context.temp_allocator,
			)
			ttfText: ^ttf.Text = ttf.CreateText(textEngine, font, textContentInCStr, 0)
			setColorResult := ttf.SetTextColor(
				ttfText,
				drawData.TextColor.r,
				drawData.TextColor.g,
				drawData.TextColor.b,
				drawData.TextColor.a,
			)
			defer ttf.DestroyText(ttfText)

			result := ttf.DrawRendererText(
				ttfText,
				drawData.TextRect.Position.x,
				drawData.TextRect.Position.y,
			)
		case dygui.RectangleDrawData:
			sdl3.SetRenderDrawBlendMode(renderer, sdl3.BLENDMODE_BLEND)
			sdl3.SetRenderDrawColor(
				renderer,
				drawData.Color.r,
				drawData.Color.g,
				drawData.Color.b,
				drawData.Color.a,
			)

			hasRoundedCorners: bool =
				drawData.CornerRadius.TL > 0 ||
				drawData.CornerRadius.TR > 0 ||
				drawData.CornerRadius.BR > 0 ||
				drawData.CornerRadius.BL > 0
			if (hasRoundedCorners) {
				drawRoundedRect(
					renderer,
					drawData.Rect,
					drawData.CornerRadius,
					drawData.Color,
					drawData.Thickness,
				)
			} else {
				rect := sdl3.FRect{}
				rect.x, rect.y = drawData.Rect.Position.x, drawData.Rect.Position.y
				rect.w, rect.h = drawData.Rect.Size.x, drawData.Rect.Size.y
				sdl3.RenderRect(renderer, &rect)
			}
		}
	}
}

FreeEngine :: proc(engineMemory: ^EngineMemory) {
	for i := 0; i < len(engineMemory.Fonts); i += 1 {
		ttf.CloseFont(engineMemory.Fonts[i])
	}
	delete(engineMemory.Fonts)

	dygui.FreeContext(engineMemory.GUIContext)

	ttf.DestroyRendererTextEngine(engineMemory.TextEngine)

	if (engineMemory.MainRenderer != nil) {
		sdl3.DestroyRenderer(engineMemory.MainRenderer)
	}

	if engineMemory.MainWindow != nil {
		sdl3.DestroyWindow(engineMemory.MainWindow)
	}
	sdl3.Quit()
	free(engineMemory)
}

LoadFont :: proc(engineMemory: ^EngineMemory, fontPath: cstring, defaultSize: f32) -> int {
	font := ttf.OpenFont(fontPath, defaultSize)
	if font == nil {
		sdl3.Log("Failed to load ttf font file: ", fontPath)
		return -1
	}

	append(&engineMemory.Fonts, font)
	return len(engineMemory.Fonts) - 1
}

@(private)
measureText :: proc(
	textContent: string,
	fontConfig: dygui.FontConfig,
	userData: rawptr,
) -> dygui.Dimensions {
	engineMemory := cast(^EngineMemory)userData
	font := engineMemory.Fonts[fontConfig.FontId]
	currentFontSize := ttf.GetFontSize(font)
	targetMeasureFontSize := cast(f32)fontConfig.FontSize

	needToChangeFontSize: bool = currentFontSize != targetMeasureFontSize
	if (needToChangeFontSize) {
		if (!ttf.SetFontSize(font, targetMeasureFontSize)) {
			return {100, 100}
			// TODO: error handling
		}
	}

	measuredTextWidth, measuredTextHeight: c.int = 0, 0
	textContentInCStr := strings.clone_to_cstring(textContent, context.temp_allocator)
	getSizeResult := ttf.GetStringSize(
		font,
		textContentInCStr,
		0,
		&measuredTextWidth,
		&measuredTextHeight,
	)

	if (needToChangeFontSize) {
		if (!ttf.SetFontSize(font, currentFontSize)) {
			// TODO: error handling
			return {100, 100}
		}
	}

	return {cast(f32)measuredTextWidth, cast(f32)measuredTextHeight}
}

@(private)
drawFilledRoundedRect :: proc(
	renderer: ^sdl3.Renderer,
	rect: dygui.Rect,
	cornerRadius: dygui.CornerRadius,
	color: [4]u8,
) {
	ARC_SEGEMENT_COUNT :: 16

	// 1 center rect + 4 fan corners
	VERTEX_COUNT :: 4 + 4 * ((ARC_SEGEMENT_COUNT + 1) + 2)

	// 5 rects + 4 fan corners
	INDICES_COUNT :: (5 * 2) * 3 + 4 * (ARC_SEGEMENT_COUNT + 2) * 3

	vertices: [VERTEX_COUNT][2]f32
	indices: [INDICES_COUNT]c.int

	// Clamp radius, the radius at the highest can only be rect.Size * 0.5
	cornerRadius := cornerRadius // We will modify the radius later, hence we need to assign it to make it mutable here.
	shortSideSizeHalved := (rect.Size.x < rect.Size.y ? rect.Size.x : rect.Size.x) * 0.5
	if (cornerRadius.TL > shortSideSizeHalved) {
		cornerRadius.TL = shortSideSizeHalved
	}
	if (cornerRadius.TR > shortSideSizeHalved) {
		cornerRadius.TR = shortSideSizeHalved
	}
	if (cornerRadius.BR > shortSideSizeHalved) {
		cornerRadius.BR = shortSideSizeHalved
	}
	if (cornerRadius.BL > shortSideSizeHalved) {
		cornerRadius.BL = shortSideSizeHalved
	}

	biggestRadius := cornerRadius.TL
	if (cornerRadius.TR > biggestRadius) {
		biggestRadius = cornerRadius.TR
	}
	if (cornerRadius.BL > biggestRadius) {
		biggestRadius = cornerRadius.BL
	}
	if (cornerRadius.BR > biggestRadius) {
		biggestRadius = cornerRadius.BR
	}

	vertexCount, indexCount: c.int = 0, 0

	//    _4___________5_
	//   / |           | \
	//  |  |     T     |  |
	// 11__0___________1__6
	//  |  |           |  |
	//  | L|     C     |R |
	// 1|  |           |  |
	// 10__3___________2__7
	//  |  |     B     |  |
	//   \_|___________|_/
	//     9           8

	// C
	centerRect: dygui.Rect = {
		Position = rect.Position + {biggestRadius, biggestRadius},
		Size     = rect.Size - 2 * {biggestRadius, biggestRadius},
	}
	{
		vertices[vertexCount] = centerRect.Position; vertexCount += 1 // 0
		vertices[vertexCount] = centerRect.Position + {centerRect.Size.x, 0}; vertexCount += 1 // 1
		vertices[vertexCount] = centerRect.Position + centerRect.Size; vertexCount += 1 // 2
		vertices[vertexCount] = centerRect.Position + {0, centerRect.Size.y}; vertexCount += 1 // 3

		indices[indexCount] = 0; indexCount += 1
		indices[indexCount] = 1; indexCount += 1
		indices[indexCount] = 3; indexCount += 1
		indices[indexCount] = 1; indexCount += 1
		indices[indexCount] = 2; indexCount += 1
		indices[indexCount] = 3; indexCount += 1
	}

	// T, L, B, R
	{
		// Tl, Tr (4, 5)
		vertices[vertexCount] = centerRect.Position + {0, -biggestRadius}; vertexCount += 1
		vertices[vertexCount] =
			centerRect.Position + {centerRect.Size.x, 0} + {0, -biggestRadius}; vertexCount += 1
		indices[indexCount] = 4; indexCount += 1
		indices[indexCount] = 5; indexCount += 1
		indices[indexCount] = 0; indexCount += 1
		indices[indexCount] = 5; indexCount += 1
		indices[indexCount] = 1; indexCount += 1
		indices[indexCount] = 0; indexCount += 1

		// Lt, Lb (6, 7)
		vertices[vertexCount] =
			centerRect.Position + {centerRect.Size.x, 0} + {biggestRadius, 0}; vertexCount += 1
		vertices[vertexCount] =
			centerRect.Position + centerRect.Size + {biggestRadius, 0}; vertexCount += 1
		indices[indexCount] = 1; indexCount += 1
		indices[indexCount] = 6; indexCount += 1
		indices[indexCount] = 2; indexCount += 1
		indices[indexCount] = 6; indexCount += 1
		indices[indexCount] = 7; indexCount += 1
		indices[indexCount] = 2; indexCount += 1

		// Br, Bl (8, 9)
		vertices[vertexCount] =
			centerRect.Position + centerRect.Size + {0, biggestRadius}; vertexCount += 1
		vertices[vertexCount] =
			centerRect.Position + {0, centerRect.Size.y} + {0, biggestRadius}; vertexCount += 1
		indices[indexCount] = 3; indexCount += 1
		indices[indexCount] = 2; indexCount += 1
		indices[indexCount] = 9; indexCount += 1
		indices[indexCount] = 2; indexCount += 1
		indices[indexCount] = 9; indexCount += 1
		indices[indexCount] = 8; indexCount += 1

		// Rb, Rt (10, 11)
		vertices[vertexCount] =
			centerRect.Position + {0, centerRect.Size.y} + {-biggestRadius, 0}; vertexCount += 1
		vertices[vertexCount] = centerRect.Position + {-biggestRadius, 0}; vertexCount += 1
		indices[indexCount] = 11; indexCount += 1
		indices[indexCount] = 0; indexCount += 1
		indices[indexCount] = 10; indexCount += 1
		indices[indexCount] = 0; indexCount += 1
		indices[indexCount] = 3; indexCount += 1
		indices[indexCount] = 10; indexCount += 1
	}

	// TL Fan
	{
		START_ANGLE_IN_DEGREE :: 180.0
		END_ANGLE_IN_DEGREE :: 90.0
		ANGLE_STEP :: (END_ANGLE_IN_DEGREE - START_ANGLE_IN_DEGREE) / ARC_SEGEMENT_COUNT
		radius := cornerRadius.TL
		fanCenter: [2]f32 = rect.Position + {radius, radius}
		cornerVertexIndex: c.int = 0
		arcStartingEdgeVertexIndex: c.int = 11
		arcEndingEdgeVertexIndex: c.int = 4

		// Populate vertices
		startingVertexIndex := vertexCount
		for i := 0; i < ARC_SEGEMENT_COUNT + 1; i += 1 {
			angleInRadian := math.to_radians(START_ANGLE_IN_DEGREE + ANGLE_STEP * cast(f32)i)

			// We need to negate the y value because up is negative Y; While in a trigonometric cooridnate system, up is positive Y.
			x := math.cos(angleInRadian) * radius
			y := -math.sin(angleInRadian) * radius
			vertices[vertexCount] = fanCenter + {x, y}; vertexCount += 1
		}

		// Populate triangles of the fan
		for i: c.int = 0; i < ARC_SEGEMENT_COUNT; i += 1 {
			indices[indexCount] = startingVertexIndex + i; indexCount += 1
			indices[indexCount] = startingVertexIndex + i + 1; indexCount += 1
			indices[indexCount] = cornerVertexIndex; indexCount += 1
		}

		// Populate triangles that connect the side rects with the fan
		indices[indexCount] = arcStartingEdgeVertexIndex; indexCount += 1
		indices[indexCount] = startingVertexIndex; indexCount += 1
		indices[indexCount] = cornerVertexIndex; indexCount += 1

		indices[indexCount] = startingVertexIndex + ARC_SEGEMENT_COUNT; indexCount += 1
		indices[indexCount] = arcEndingEdgeVertexIndex; indexCount += 1
		indices[indexCount] = cornerVertexIndex; indexCount += 1
	}

	// TR Fan
	{
		START_ANGLE_IN_DEGREE :: 90.0
		END_ANGLE_IN_DEGREE :: 0.0
		ANGLE_STEP :: (END_ANGLE_IN_DEGREE - START_ANGLE_IN_DEGREE) / ARC_SEGEMENT_COUNT
		radius := cornerRadius.TR
		fanCenter: [2]f32 = rect.Position + {rect.Size.x, 0} + {-radius, radius}
		cornerVertexIndex: c.int = 1
		arcStartingEdgeVertexIndex: c.int = 5
		arcEndingEdgeVertexIndex: c.int = 6

		// Populate vertices
		startingVertexIndex := vertexCount
		for i := 0; i < ARC_SEGEMENT_COUNT + 1; i += 1 {
			angleInRadian := math.to_radians(START_ANGLE_IN_DEGREE + ANGLE_STEP * cast(f32)i)

			// We need to negate the y value because up is negative Y; While in a trigonometric cooridnate system, up is positive Y.
			x := math.cos(angleInRadian) * radius
			y := -math.sin(angleInRadian) * radius
			vertices[vertexCount] = fanCenter + {x, y}; vertexCount += 1
		}

		// Populate triangles of the fan
		for i: c.int = 0; i < ARC_SEGEMENT_COUNT; i += 1 {
			indices[indexCount] = startingVertexIndex + i; indexCount += 1
			indices[indexCount] = startingVertexIndex + i + 1; indexCount += 1
			indices[indexCount] = cornerVertexIndex; indexCount += 1
		}

		// Populate triangles that connect the side rects with the fan
		indices[indexCount] = arcStartingEdgeVertexIndex; indexCount += 1
		indices[indexCount] = startingVertexIndex; indexCount += 1
		indices[indexCount] = cornerVertexIndex; indexCount += 1

		indices[indexCount] = startingVertexIndex + ARC_SEGEMENT_COUNT; indexCount += 1
		indices[indexCount] = arcEndingEdgeVertexIndex; indexCount += 1
		indices[indexCount] = cornerVertexIndex; indexCount += 1
	}

	// BR Fan
	{
		START_ANGLE_IN_DEGREE :: 0.0
		END_ANGLE_IN_DEGREE :: -90.0
		ANGLE_STEP :: (END_ANGLE_IN_DEGREE - START_ANGLE_IN_DEGREE) / ARC_SEGEMENT_COUNT
		radius := cornerRadius.BR
		fanCenter: [2]f32 = rect.Position + rect.Size - {radius, radius}
		cornerVertexIndex: c.int = 2
		arcStartingEdgeVertexIndex: c.int = 7
		arcEndingEdgeVertexIndex: c.int = 8

		// Populate vertices
		startingVertexIndex := vertexCount
		for i := 0; i < ARC_SEGEMENT_COUNT + 1; i += 1 {
			angleInRadian := math.to_radians(START_ANGLE_IN_DEGREE + ANGLE_STEP * cast(f32)i)

			// We need to negate the y value because up is negative Y; While in a trigonometric cooridnate system, up is positive Y.
			x := math.cos(angleInRadian) * radius
			y := -math.sin(angleInRadian) * radius
			vertices[vertexCount] = fanCenter + {x, y}; vertexCount += 1
		}

		// Populate triangles of the fan
		for i: c.int = 0; i < ARC_SEGEMENT_COUNT; i += 1 {
			indices[indexCount] = startingVertexIndex + i; indexCount += 1
			indices[indexCount] = startingVertexIndex + i + 1; indexCount += 1
			indices[indexCount] = cornerVertexIndex; indexCount += 1
		}

		// Populate triangles that connect the side rects with the fan
		indices[indexCount] = arcStartingEdgeVertexIndex; indexCount += 1
		indices[indexCount] = startingVertexIndex; indexCount += 1
		indices[indexCount] = cornerVertexIndex; indexCount += 1

		indices[indexCount] = startingVertexIndex + ARC_SEGEMENT_COUNT; indexCount += 1
		indices[indexCount] = arcEndingEdgeVertexIndex; indexCount += 1
		indices[indexCount] = cornerVertexIndex; indexCount += 1
	}

	// BL Fan
	{
		START_ANGLE_IN_DEGREE :: -90.0
		END_ANGLE_IN_DEGREE :: -180.0
		ANGLE_STEP :: (END_ANGLE_IN_DEGREE - START_ANGLE_IN_DEGREE) / ARC_SEGEMENT_COUNT
		radius := cornerRadius.BL
		fanCenter: [2]f32 = rect.Position + {0, rect.Size.y} + {radius, -radius}
		cornerVertexIndex: c.int = 3
		arcStartingEdgeVertexIndex: c.int = 9
		arcEndingEdgeVertexIndex: c.int = 10

		// Populate vertices
		startingVertexIndex := vertexCount
		for i := 0; i < ARC_SEGEMENT_COUNT + 1; i += 1 {
			angleInRadian := math.to_radians(START_ANGLE_IN_DEGREE + ANGLE_STEP * cast(f32)i)

			// We need to negate the y value because up is negative Y; While in a trigonometric cooridnate system, up is positive Y.
			x := math.cos(angleInRadian) * radius
			y := -math.sin(angleInRadian) * radius
			vertices[vertexCount] = fanCenter + {x, y}; vertexCount += 1
		}

		// Populate triangles of the fan
		for i: c.int = 0; i < ARC_SEGEMENT_COUNT; i += 1 {
			indices[indexCount] = startingVertexIndex + i; indexCount += 1
			indices[indexCount] = startingVertexIndex + i + 1; indexCount += 1
			indices[indexCount] = cornerVertexIndex; indexCount += 1
		}

		// Populate triangles that connect the side rects with the fan
		indices[indexCount] = arcStartingEdgeVertexIndex; indexCount += 1
		indices[indexCount] = startingVertexIndex; indexCount += 1
		indices[indexCount] = cornerVertexIndex; indexCount += 1

		indices[indexCount] = startingVertexIndex + ARC_SEGEMENT_COUNT; indexCount += 1
		indices[indexCount] = arcEndingEdgeVertexIndex; indexCount += 1
		indices[indexCount] = cornerVertexIndex; indexCount += 1
	}

	sdlVertices: [VERTEX_COUNT]sdl3.Vertex
	for i: c.int = 0; i < vertexCount; i += 1 {
		fColor: sdl3.FColor = {
			cast(f32)color.r / 255,
			cast(f32)color.g / 255,
			cast(f32)color.b / 255,
			cast(f32)color.a / 255,
		}
		sdlVertices[i] = {
			position  = cast(sdl3.FPoint)vertices[i],
			color     = fColor,
			tex_coord = {0, 0},
		}
	}
	sdl3.RenderGeometry(renderer, nil, &sdlVertices[0], vertexCount, &indices[0], indexCount)

	/*
	// Debug
	sdlPoints : [VERTEX_COUNT]sdl3.FPoint
	for i : c.int = 0; i < vertexCount; i += 1 
	{
		sdlPoints[i] = cast(sdl3.FPoint) vertices[i]
	} 
	sdl3.SetRenderDrawColor(renderer, 255, 255, 255, sdl3.ALPHA_OPAQUE)
	sdl3.RenderPoints(renderer, &sdlPoints[12], vertexCount - 12)*/
}

@(private)
drawRoundedRect :: proc(
	renderer: ^sdl3.Renderer,
	rect: dygui.Rect,
	cornerRadius: dygui.CornerRadius,
	color: [4]u8,
	thickness: f32,
) {
	//    _4_____T_____5_
	//   /               \
	//  |                 |
	// 11                 6
	//  |                 |
	//  L                 T
	//  |                 |
	// 10                 7
	//  |                 |
	//   \_ _____B_____ _/
	//     9           8

	// Edges
	{
		sdl3.SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a)

		// T
		{
			position := rect.Position + {cornerRadius.TL, 0}
			size: [2]f32 = {rect.Size.x - cornerRadius.TL - cornerRadius.TR, thickness}

			lineRect: sdl3.FRect = {
				x = position.x,
				y = position.y,
				w = size.x,
				h = size.y,
			}
			sdl3.RenderFillRect(renderer, &lineRect)
		}

		// R
		{
			position := rect.Position + {rect.Size.x - thickness, 0} + {0, cornerRadius.TR}
			size: [2]f32 = {thickness, rect.Size.y - cornerRadius.TR - cornerRadius.BR}

			lineRect: sdl3.FRect = {
				x = position.x,
				y = position.y,
				w = size.x,
				h = size.y,
			}
			sdl3.RenderFillRect(renderer, &lineRect)
		}

		// B
		{
			position := rect.Position + {0, rect.Size.y} + {cornerRadius.BL, -thickness}
			size: [2]f32 = {rect.Size.x - cornerRadius.BL - cornerRadius.BR, thickness}

			lineRect: sdl3.FRect = {
				x = position.x,
				y = position.y,
				w = size.x,
				h = size.y,
			}
			sdl3.RenderFillRect(renderer, &lineRect)
		}

		// L
		{
			position := rect.Position + {0, cornerRadius.TL}
			size: [2]f32 = {thickness, rect.Size.y - cornerRadius.TL - cornerRadius.BL}

			lineRect: sdl3.FRect = {
				x = position.x,
				y = position.y,
				w = size.x,
				h = size.y,
			}
			sdl3.RenderFillRect(renderer, &lineRect)
		}
	}

	// Arcs
	{
		// TL
		if (cornerRadius.TL > 0) {
			center := rect.Position + cornerRadius.TL
			radius := cornerRadius.TL

			drawArc(renderer, center, radius, thickness, color, 90, 180)
		}

		// TR
		if (cornerRadius.TR > 0) {
			center := rect.Position + {rect.Size.x, 0} + {-cornerRadius.TR - 1, cornerRadius.TR}
			radius := cornerRadius.TR

			drawArc(renderer, center, radius, thickness, color, 90, 0)
		}

		// BR
		if (cornerRadius.BR > 0) {
			center := rect.Position + rect.Size + {-cornerRadius.BR - 1, -cornerRadius.BR - 1}
			radius := cornerRadius.BR

			drawArc(renderer, center, radius, thickness, color, 0, -90)
		}

		// BL
		if (cornerRadius.BL > 0) {
			center := rect.Position + {0, rect.Size.y} + {cornerRadius.BL, -cornerRadius.BL - 1}
			radius := cornerRadius.BL

			drawArc(renderer, center, radius, thickness, color, -90, -180)
		}
	}
}

@(private)
drawArc :: proc(
	renderer: ^sdl3.Renderer,
	center: [2]f32,
	radius: f32,
	thinkness: f32,
	color: [4]u8,
	startAngleInDegree: f32,
	endAngleInDegree: f32,
) {
	ARC_SEGEMENT_COUNT_90 :: 16 // 90 degrees -> 16, 180 degrees -> 32 etc

	sdl3.SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a)

	angleDiffInDegree := math.abs(endAngleInDegree - startAngleInDegree)
	arcSegmentCount := cast(int)math.floor(
		angleDiffInDegree > 90 ? ARC_SEGEMENT_COUNT_90 * angleDiffInDegree / 90.0 - 1 : ARC_SEGEMENT_COUNT_90,
	)

	startAngleInRadian := math.to_radians(startAngleInDegree)
	endAngleInRadian := math.to_radians(endAngleInDegree)
	angleStep := (endAngleInRadian - startAngleInRadian) / cast(f32)arcSegmentCount

	thicknessInInt: u32 = cast(u32)math.round(thinkness)
	thicknessInInt = math.max(thicknessInInt, 1)
	if (thicknessInInt == 1) {
		// We will only have arcSegmentCount + 1 points but just to make the array static size, we make the array as big as the biggest possible size,
		// which is when the arc is a circle (360 degrees)
		points: [ARC_SEGEMENT_COUNT_90 * 4]sdl3.FPoint
		for i := 0; i <= arcSegmentCount; i += 1 {
			angleInRadian := startAngleInRadian + angleStep * cast(f32)i
			points[i] = {
				math.round(center.x + math.cos(angleInRadian) * radius),
				math.round(center.y - math.sin(angleInRadian) * radius),
			}
		}
		sdl3.RenderLines(renderer, &points[0], cast(c.int)arcSegmentCount + 1)
	} else {
		thicknessStep: f32 = 0.4 // arbitary value to avoid overlapping lines issue.
		for t := thicknessStep; t < thinkness - thicknessStep; t += thicknessStep {
			// We will only have arcSegmentCount + 1 points but just to make the array static size, we make the array as big as the biggest possible size,
			// which is when the arc is a circle (360 degrees)
			points: [ARC_SEGEMENT_COUNT_90 * 4]sdl3.FPoint
			clampedRadius := math.max(radius - t, 1.0) // To make sure the value is at least 1

			for i := 0; i <= arcSegmentCount; i += 1 {
				angleInRadian := startAngleInRadian + angleStep * cast(f32)i
				points[i] = {
					math.round(center.x + math.cos(angleInRadian) * clampedRadius),
					math.round(center.y - math.sin(angleInRadian) * clampedRadius),
				}
			}

			sdl3.RenderLines(renderer, &points[0], cast(c.int)arcSegmentCount + 1)
		}
	}
}
