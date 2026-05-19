package app

import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import "core:unicode/utf8"

import dye "../dye"
import dygui "../dye/gui"
import hm "../dye/handle_map"

SPAWN_PER_MINUTES :: 20

EntityHandle :: distinct hm.Handle
Entity :: struct {
	Handle:         EntityHandle,
	Position:       linalg.Vector2f32,
	TypeText:       [64]rune,
	TypeTextLength: int,
}

GameMemory :: struct {
	ButtonString:   [dynamic]rune,
	Entities:       hm.HandleMap(Entity, EntityHandle, 1024),
	NextSpawnTimer: f32,
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
}

OnUpdate :: proc(deltaTime: f32) {
	text := g_Memory.EngineMemory.Input.Text
	for i := 0; i < text.Length; i += 1 {
		append(&g_Memory.Game.ButtonString, text.Buffer[i])
	}

	// Update spawn timer.
	g_Memory.Game.NextSpawnTimer -= deltaTime
	if (g_Memory.Game.NextSpawnTimer <= 0) {
		g_Memory.Game.NextSpawnTimer += 60 / SPAWN_PER_MINUTES
		spawnEntityWithRandomWord()
	}

	// Update entity movement.
	itr := hm.MakeIter(&g_Memory.Game.Entities)
	for entity in hm.Iter(&itr) {
		entity.Position += {0, 10 * deltaTime}
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

	hm.AddWithUndo(&g_Memory.Game.Entities, newEntity)
}

OnImGui :: proc(deltaTime: f32) {
	style := dygui.GetStyle()
	style.Variables.Button.InnerBorderThickness = 2
	dygui.SetNexItemSize({150, 0})
	if (dygui.Button("Test Button", {300, 250})) {
		fmt.println("Test Button with Text Pressed")
	}

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
	if (dygui.Button("東西", {100, 200})) {
		fmt.println("Something...")
	}
	buttonName := utf8.runes_to_string(g_Memory.Game.ButtonString[:], context.temp_allocator)
	if (dygui.Button(buttonName, {100, 300})) {
		fmt.println(buttonName)
	}

	itr := hm.MakeIter(&g_Memory.Game.Entities)
	for entity in hm.Iter(&itr) {
		btnName := utf8.runes_to_string(
			entity.TypeText[:entity.TypeTextLength],
			context.temp_allocator,
		)
		if dygui.Button(btnName, entity.Position) {
			hm.RemoveWithUndo(&g_Memory.Game.Entities, entity.Handle)
		}
	}

	dygui.SetNexItemSize({cast(f32)g_Memory.EngineMemory.MainWindowSettings.Width, 0})
	dygui.Text("標題文字在這裡TESTING", {0, 32})
	dygui.PopFontConfig()
	if (dygui.Button("Flo", {100, 400})) {
	}
}

OnRender :: proc(deltaTime: f32) {

}

FreeGameMemory :: proc(memory: ^GameMemory) {
	delete(memory.ButtonString)
	hm.Delete(&memory.Entities)
}
