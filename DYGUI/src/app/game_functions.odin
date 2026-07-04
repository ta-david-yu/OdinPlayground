package app

import hm "core:container/handle_map"
import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"

import "vendor:sdl3"

import dye "../dye"
import dygui "../dye/gui"

SPAWN_PER_MINUTES :: 512


vertices: [3]dye.Vertex = {
	{{0, 0.5, 0.0}, {1, 0, 0, 1}},
	{{-0.5, -0.5, 0.0}, {1, 1, 0, 1}},
	{{0.5, -0.5, 0.0}, {1, 0, 1, 1}},
}

EntityHandle :: distinct hm.Handle64
Entity :: struct {
	handle:         EntityHandle,
	Position:       linalg.Vector2f32,
	TypeText:       [64]rune,
	TypeTextLength: int,
}

GameMemory :: struct {
	TitleTextString:  [dynamic]rune,
	ButtonString:     [dynamic]rune,
	Entities:         hm.Dynamic_Handle_Map(Entity, EntityHandle),
	NextSpawnTimer:   f32,
	ChineseFont:      dye.AssetHandle,
	EnglishFont:      dye.AssetHandle,
	GraphicsPipeline: dye.AssetHandle,
	VertexBuffer:     ^sdl3.GPUBuffer,
	TransferBuffer:   ^sdl3.GPUTransferBuffer,
}

OnAfterInitEngineSystems :: proc() {
	g_Memory.EngineMemory.ClearColor = {180, 180, 180, 255}

	g_Memory.Game.EnglishFont, _ = dye.Assets_GetOrLoadFont("assets/fonts/m6x11plus.ttf", 36)
	g_Memory.Game.ChineseFont, _ = dye.Assets_GetOrLoadFont("assets/fonts/Cubic_11.ttf", 33)

	dygui.SetMainFontConfig(
		{FontId = cast(dygui.ID)g_Memory.Game.EnglishFont.PathHash, FontSize = 18},
	)

	style := dygui.GetStyle()
	style.Colors.Text = {0, 0, 0, 255}

	style.Colors.Button.Idle = {180, 180, 180, 255}
	style.Colors.Button.Hovered = {255, 255, 255, 255}
	style.Colors.Button.Active = {200, 200, 200, 255}
	style.Colors.Shadow = {0, 0, 0, 128}

	style.Variables.Button.FramePaddingBottom = 5
	style.Variables.Button.FramePaddingTop = 5
	style.Variables.Button.FramePaddingLeft = 10
	style.Variables.Button.FramePaddingRight = 10
	style.Variables.Button.CornerRadius = {
		TL = 3,
		TR = 3,
		BR = 3,
		BL = 3,
	}
	style.Variables.Shadow.Offset = {4, 5}
	style.Variables.Shadow.Softness = 5

	style.Variables.Button.InnerBorderThickness = 2
	style.Colors.Button.InnerBorderIdle = 255
	style.Colors.Button.InnerBorderHovered = 255
	style.Colors.Button.InnerBorderActive = 255

	style.Variables.Button.OuterBorderThickness = 2
	style.Colors.Button.OuterBorderIdle = {0, 0, 0, 255}
	style.Colors.Button.OuterBorderHovered = {0, 0, 0, 255}
	style.Colors.Button.OuterBorderActive = {0, 0, 0, 255}

	// Create vertex buffer on gpu
	vertexBufferInfo: sdl3.GPUBufferCreateInfo = {
		size  = size_of(vertices),
		usage = {.VERTEX},
	}
	g_Memory.Game.VertexBuffer = sdl3.CreateGPUBuffer(
		g_Memory.EngineMemory.GPUDevice,
		vertexBufferInfo,
	)

	// Create transfer buffer to upload data to the vertex buffer
	transferInfo: sdl3.GPUTransferBufferCreateInfo = {
		size  = size_of(vertices),
		usage = .UPLOAD,
	}
	g_Memory.Game.TransferBuffer = sdl3.CreateGPUTransferBuffer(
		g_Memory.EngineMemory.GPUDevice,
		transferInfo,
	)

	// Fill the transfer buffer with data

	// Map the transfer buffer to a pointer
	data := transmute([^]dye.Vertex)sdl3.MapGPUTransferBuffer(
		g_Memory.EngineMemory.GPUDevice,
		g_Memory.Game.TransferBuffer,
		false,
	)
	// Fill the pointer location with vertices data
	mem.copy(data, raw_data(vertices[:]), size_of(vertices))

	// Unmap the transfer buffer from the pointer
	sdl3.UnmapGPUTransferBuffer(g_Memory.EngineMemory.GPUDevice, g_Memory.Game.TransferBuffer)

	// Copy pass that copies the transfer buffer data to the vertex buffer
	{
		commandBuffer: ^sdl3.GPUCommandBuffer = sdl3.AcquireGPUCommandBuffer(
			g_Memory.EngineMemory.GPUDevice,
		)

		if commandBuffer == nil {
			sdl3.Log("Failed to acquire command buffer: %s", sdl3.GetError())
		}

		copyPass := sdl3.BeginGPUCopyPass(commandBuffer)
		transferBufferLocation: sdl3.GPUTransferBufferLocation = {
			transfer_buffer = g_Memory.Game.TransferBuffer,
			offset          = 0,
		}

		vertexBufferRegion: sdl3.GPUBufferRegion = {
			buffer = g_Memory.Game.VertexBuffer,
			size   = size_of(vertices),
			offset = 0,
		}

		// Execute the upload
		sdl3.UploadToGPUBuffer(copyPass, transferBufferLocation, vertexBufferRegion, false)

		sdl3.EndGPUCopyPass(copyPass)
		if !sdl3.SubmitGPUCommandBuffer(commandBuffer) {
			sdl3.Log("Failed to submit gpu command buffer: %s", sdl3.GetError())
		}
	}

	assetHandle, err := dye.Assets_GetOrLoadGraphicsPipeline(
		"assets/shaders/vertex.vert.spv",
		"assets/shaders/fragment.frag.spv",
	)
	assert(err == nil)

	g_Memory.Game.GraphicsPipeline = assetHandle

	hm.dynamic_init(&g_Memory.Game.Entities, context.allocator)
}

OnUpdate :: proc(deltaTime: f32) {
	text := g_Memory.EngineMemory.Input.Text
	for i := 0; i < text.Length; i += 1 {
		append(&g_Memory.Game.ButtonString, text.Buffer[i])
	}

	// Update spawn timer.
	if dye.Input_IsMouseButton(&g_Memory.EngineMemory.Input, dye.MouseButton.Right) {
		g_Memory.Game.NextSpawnTimer -= deltaTime
		if (g_Memory.Game.NextSpawnTimer <= 0) {
			g_Memory.Game.NextSpawnTimer += 60.0 / SPAWN_PER_MINUTES
			spawnEntityWithRandomWord()
		}
	}

	// Update entity movement.
	itr := hm.iterator_make(&g_Memory.Game.Entities)
	for entity, handle in hm.iterate(&itr) {
		entity.Position += {0, 100 * deltaTime}
	}
}

@(private = "file")
spawnEntityWithRandomWord :: proc() {
	posX := rand.int_max(cast(int)g_Memory.EngineMemory.MainWindowSettings.Width)

	newEntity: Entity = {
		Position       = {cast(f32)posX, 0},
		TypeText       = {},
		TypeTextLength = 0,
	}
	runesToCopy := utf8.string_to_runes("測試", context.temp_allocator)
	newEntity.TypeTextLength = min(len(runesToCopy), len(newEntity.TypeText))
	for i := 0; i < newEntity.TypeTextLength; i += 1 {
		newEntity.TypeText[i] = runesToCopy[i]
	}

	h := hm.add(&g_Memory.Game.Entities, newEntity)
}

OnImGui :: proc(deltaTime: f32) {
	style := dygui.GetStyle()
	style.Variables.Button.InnerBorderThickness = 2

	dygui.PushFontConfig(
		{FontId = cast(dygui.ID)g_Memory.Game.ChineseFont.PathHash, FontSize = 22},
	) // Set font Id for chinese.

	dygui.SetNexItemSize({150, 0})
	if (dygui.Button("改顏色", {400, 300})) {
		g_Memory.EngineMemory.ClearColor = {
			u8(rand.int_max(255)),
			u8(rand.int_max(255)),
			u8(rand.int_max(255)),
			255,
		}
	}
	if (dygui.Button("重置 DLL", {400, 400})) {
		g_Memory.RequireHardReset = true
	}
	buttonName := utf8.runes_to_string(g_Memory.Game.ButtonString[:], context.temp_allocator)
	if (dygui.Button(buttonName, {100, 300})) {
		fmt.println(buttonName)
	}


	itr := hm.iterator_make(&g_Memory.Game.Entities)
	for entity, handle in hm.iterate(&itr) {
		btnName := utf8.runes_to_string(
			entity.TypeText[:entity.TypeTextLength],
			context.temp_allocator,
		)
		if dygui.Button(btnName, entity.Position) {
			hm.remove(&g_Memory.Game.Entities, handle)
		}
	}

	dygui.SetNexItemSize({cast(f32)g_Memory.EngineMemory.MainWindowSettings.Width, 0})

	dygui.PopFontConfig()

	{
		titleTextStrBuff := new([64]byte, context.temp_allocator)
		titleTextStr := strconv.write_int(
			titleTextStrBuff[:],
			cast(i64)hm.len(g_Memory.Game.Entities),
			10,
		)
		dygui.Text(titleTextStr, {0, 32})
	}

	{
		stringBuilder := strings.builder_make(context.temp_allocator)
		strings.write_string(&stringBuilder, "fps: ")
		strings.write_f64(&stringBuilder, g_Memory.EngineMemory.Fps, 'f')
		dygui.Text(strings.to_string(stringBuilder), {20, 48})
	}

}

OnRender :: proc(deltaTime: f32) {
	commandBuffer: ^sdl3.GPUCommandBuffer = sdl3.AcquireGPUCommandBuffer(
		g_Memory.EngineMemory.GPUDevice,
	)

	if commandBuffer == nil {
		sdl3.Log("Failed to acquire command buffer: %s", sdl3.GetError())
	}

	// Start the render pass that draws on the window color target
	{
		windowSwapChainTexture: ^sdl3.GPUTexture
		if !sdl3.WaitAndAcquireGPUSwapchainTexture(
			commandBuffer,
			g_Memory.EngineMemory.MainWindow,
			&windowSwapChainTexture,
			nil,
			nil,
		) {
			sdl3.Log("Failed to acquire GPU swapchain texture: %s", sdl3.GetError())
		}

		clearFColor := cast(sdl3.FColor)(cast([4]f32)g_Memory.EngineMemory.ClearColor / 255.0)
		windoColorTargetInfo: sdl3.GPUColorTargetInfo = {
			texture     = windowSwapChainTexture,
			cycle       = true,
			load_op     = sdl3.GPULoadOp.CLEAR,
			store_op    = sdl3.GPUStoreOp.STORE,
			clear_color = clearFColor,
		}

		renderPass: ^sdl3.GPURenderPass = sdl3.BeginGPURenderPass(
			commandBuffer,
			&windoColorTargetInfo,
			1,
			nil,
		)

		graphicsPipeline, err := dye.Assets_GetGraphicsPipeline(g_Memory.Game.GraphicsPipeline)
		assert(err == nil)

		sdl3.BindGPUGraphicsPipeline(renderPass, graphicsPipeline.Pipeline)

		bufferBindings: [1]sdl3.GPUBufferBinding = {
			{buffer = g_Memory.Game.VertexBuffer, offset = 0},
		}

		sdl3.BindGPUVertexBuffers(renderPass, 0, raw_data(bufferBindings[:]), 1)

		UniformBuffer :: struct {
			time: f32,
		}
		uniform: UniformBuffer = {}
		sdl3.PushGPUFragmentUniformData(commandBuffer, 0, &uniform, size_of(UniformBuffer))
		sdl3.DrawGPUPrimitives(renderPass, 3, 1, 0, 0)

		sdl3.EndGPURenderPass(renderPass)
	}

	if !sdl3.SubmitGPUCommandBuffer(commandBuffer) {
		sdl3.Log("Failed to submit gpu command buffer: %s", sdl3.GetError())
	}
}

FreeGameRelatedMemory :: proc() {
	sdl3.ReleaseGPUTransferBuffer(g_Memory.EngineMemory.GPUDevice, g_Memory.Game.TransferBuffer)
	sdl3.ReleaseGPUBuffer(g_Memory.EngineMemory.GPUDevice, g_Memory.Game.VertexBuffer)
	delete(g_Memory.Game.TitleTextString)
	delete(g_Memory.Game.ButtonString)
	hm.dynamic_destroy(&g_Memory.Game.Entities)
}
