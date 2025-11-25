package main

import "core:dynlib"
import "core:os"

AppAPI :: struct {
	Info:                 struct {
		DLLTimeStamp: os.File_Time,
		APIVersion:   int,
	},
	Library:              dynlib.Library,
	GetAppMemory:         proc() -> rawptr,
	ShouldExitUpdateLoop: proc() -> bool,
	Init:                 proc(),
	OneLoop:              proc(),
	HotReload:            proc(appMemory: rawptr),
	Shutdown:             proc(),
}

g_Api: AppAPI = {}

main :: proc() {
	_, result := dynlib.initialize_symbols(&g_Api, "app.dll", "App_", "Library")
	defer dynlib.unload_library(g_Api.Library)

	g_Api.Init()

	for {
		g_Api.OneLoop()
		if (g_Api.ShouldExitUpdateLoop()) {
			break
		}
	}

	g_Api.Shutdown()
}
