package app

import "core:fmt"

import dye "../dye"
import dygui "../dye/gui"

OnAfterInitEngineSystems :: proc() {
	dye.LoadFont(g_Memory.EngineMemory, "fonts/m6x11plus.ttf", 36)
	dye.LoadFont(g_Memory.EngineMemory, "fonts/Cubic_11.ttf", 33)

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
		fmt.println("Something...")
	}
	if (dygui.Button("印出東西", {400, 400})) {
	}
	if (dygui.Button("東西", {100, 200})) {
	}

	dygui.SetNexItemSize({cast(f32)g_Memory.EngineMemory.MainWindowSettings.Width, 0})
	dygui.Text("標題文字在這裡TESTING", {0, 32})
	dygui.PopFontConfig()
	if (dygui.Button("Flo", {100, 400})) {
	}
}

OnRender :: proc(deltaTime: f32) {

}
