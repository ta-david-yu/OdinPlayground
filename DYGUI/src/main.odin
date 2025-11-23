package main

import "core:math/rand"
import "core:c"
import "core:fmt"

import dygui "dygui"
import dye "dye"


MainWindowWidth : int = 960
MainWindowHeight : int = 720

ButtonPosition : [2]f32 = { 400, 300 }

main :: proc() 
{
	dye.Init({ Name = "DYE", Width = cast(c.int) MainWindowWidth, Height = cast(c.int) MainWindowHeight })
	
	gameFunctions : dye.GameFunctions = 
	{
		OnBeforeEngineStarts = OnBeforeEngineStarts,
		OnUpdate = OnUpdate,
		OnImGui = OnImGui,
		OnRender = OnRender
	}
	dye.SetGameFunctions(gameFunctions)
	
	dye.StartLoop()
	
	dye.Shutdown()
}

OnBeforeEngineStarts :: proc(result: bool)
{
	mainFontIndex := dye.LoadFont("fonts/m6x11plus.ttf", 36)
	if mainFontIndex < 0
	{
		fmt.println("Failed to load font: ", "fonts/m6x11plus.ttf")
	}
	
	chineseFontIndex := dye.LoadFont("fonts/Cubic_11.ttf", 33)
	if chineseFontIndex < 0
	{
		fmt.println("Failed to load font: ", "fonts/Cubic_11.ttf")
	}

	dygui.SetMainFontConfig({ FontId = cast(u16) mainFontIndex, FontSize = 18 })
	
	style := dygui.GetStyle()
	style.Colors.Text = { 0, 0, 0, 255 }
	
	style.Colors.Button.Idle = { 180, 180, 180, 255 }
	style.Colors.Button.Hovered = { 255, 255, 255, 255 }
	style.Colors.Button.Active = { 200, 200, 200, 255 }
	style.Colors.Shadow = { 0, 0, 0, 128 }

	style.Variables.Button.FramePaddingBottom = 5
	style.Variables.Button.FramePaddingTop = 5
	style.Variables.Button.FramePaddingLeft = 10
	style.Variables.Button.FramePaddingRight = 10
	style.Variables.Button.CornerRadius = { TL = 3, TR = 3, BR = 3, BL = 3 }
	style.Variables.Shadow.Offset = { 4, 5 }
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

OnUpdate :: proc(deltaTime: f32)
{

}

OnImGui :: proc(deltaTime: f32)
{
	dygui.SetNexItemSize({ 150, 0 })
	if (dygui.Button("Test Button", { 300, 250 }))
	{
		fmt.println("Test Button with Text Pressed")
	}

	dygui.PushFontConfig({ FontId = 1, FontSize = 22 }) // Font Id 1 is for chinese.
	{
		if (dygui.Button("隨機", ButtonPosition))
		{
			buttonRect := dygui.GetLastItemRect()
			newX := rand.float32_range(0, cast(f32)MainWindowWidth - buttonRect.Size.x)
			newY := rand.float32_range(0, cast(f32)MainWindowHeight - buttonRect.Size.y)
			ButtonPosition = { newX, newY }
			fmt.println(ButtonPosition)
		}
		
		dygui.SetNexItemSize({ cast(f32) MainWindowWidth, 0 })
		dygui.Text("標題文字在這裡", { 0, 32 })
	}	
	dygui.PopFontConfig()
}

OnRender :: proc(deltaTime: f32)
{

}
