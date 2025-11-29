package app

import "core:fmt"

import "../dye"

AppMemory :: struct {
	EngineMemory:     ^dye.EngineMemory,
	RequireHardReset: bool,
}
g_Memory: ^AppMemory

@(export)
App_GetAppMemory :: proc() -> rawptr {
	return g_Memory
}

@(export)
App_ShouldExitUpdateLoop :: proc() -> bool {
	return g_Memory.EngineMemory.ExitRequested
}

@(export)
App_RequireHardReset :: proc() -> bool {
	return g_Memory.RequireHardReset
}

@(export)
App_Init :: proc() {
	fmt.println("Init")
	g_Memory = new(AppMemory)

	g_Memory.EngineMemory = dye.AllocateEngine()
	g_Memory.EngineMemory.MainWindowSettings = {
		Name   = "DYE",
		Width  = 960,
		Height = 720,
	}

	dye.InitEngineSystems(g_Memory.EngineMemory)
	OnAfterInitEngineSystems()
}

@(export)
App_OneLoop :: proc() {
	dye.OnEngineUpdate(
		g_Memory.EngineMemory,
		{OnUpdate = OnUpdate, OnImGui = OnImGui, OnRender = OnRender},
	)
}

@(export)
App_HotReload :: proc(appMemory: ^AppMemory) {
	g_Memory = appMemory
	dye.OnHotReload(g_Memory.EngineMemory)
}

@(export)
App_Shutdown :: proc() {
	fmt.println("Shutdown")
	dye.FreeEngine(g_Memory.EngineMemory)
	free(g_Memory)
}
