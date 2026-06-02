package app

import hm "core:container/handle_map"
import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"

import "vendor:sdl3"

import dye "../dye"
import dygui "../dye/gui"
import prof "../dye/prof"

SPAWN_PER_MINUTES :: 512

EntityHandle :: distinct hm.Handle64
Entity :: struct {
	handle:         EntityHandle,
	Position:       linalg.Vector2f32,
	TypeText:       [64]rune,
	TypeTextLength: int,
}

GameMemory :: struct {
	TitleTextString: [dynamic]rune,
	ButtonString:    [dynamic]rune,
	Entities:        hm.Dynamic_Handle_Map(Entity, EntityHandle),
	NextSpawnTimer:  f32,
}

OnAfterInitEngineSystems :: proc() {
	g_Memory.EngineMemory.RendererClearColor = {180, 180, 180, 255}

	dye.LoadFont(g_Memory.EngineMemory, "assets/fonts/m6x11plus.ttf", 36)
	dye.LoadFont(g_Memory.EngineMemory, "assets/fonts/Cubic_11.ttf", 33)

	dygui.SetMainFontConfig({FontId = 0, FontSize = 18})

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

	// Spawn 100 entities on init
	for i in 0 ..< 5 {
		spawnEntityWithRandomWord()
	}
}

OnUpdate :: proc(deltaTime: f32) {
	text := g_Memory.EngineMemory.Input.Text
	for i := 0; i < text.Length; i += 1 {
		append(&g_Memory.Game.ButtonString, text.Buffer[i])
	}

	// Update spawn timer.
	if dye.IsMouseButton(&g_Memory.EngineMemory.Input, dye.MouseButton.Right) {
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

	dygui.PushFontConfig({FontId = 1, FontSize = 22}) // Font Id 1 is for chinese.

	dygui.SetNexItemSize({150, 0})
	if (dygui.Button("改顏色", {400, 300})) {
		g_Memory.EngineMemory.RendererClearColor = {
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

	sdl3.SetRenderDrawColor(g_Memory.EngineMemory.MainRenderer, 255, 0, 0, 255)

	rect := sdl3.FRect{}
	rect.x, rect.y = 0, 0
	rect.w, rect.h = 50, 50
	for i in 0 ..< 100 {
		sdl3.RenderFillRect(g_Memory.EngineMemory.MainRenderer, &rect)
	}
}

FreeGameMemory :: proc(memory: ^GameMemory) {
	delete(memory.TitleTextString)
	delete(memory.ButtonString)
	hm.dynamic_destroy(&memory.Entities)
}
