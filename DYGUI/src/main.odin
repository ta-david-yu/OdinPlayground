package main

import "core:dynlib"
import "core:fmt"
import "core:os"

AppAPI :: struct {
	Info:                 struct {
		DLLTimestamp: os.File_Time,
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
	apiVersion := 0
	api, result := LoadAppAPI("app", apiVersion, "App_")
	defer UnloadAppAPI(api)

	/*
	_, result := dynlib.initialize_symbols(&g_Api, "app.dll", "App_", "Library")
	defer dynlib.unload_library(g_Api.Library)*/

	api.Init()

	for {
		api.OneLoop()
		if (api.ShouldExitUpdateLoop()) {
			break
		}
	}

	api.Shutdown()
}


LoadAppAPI :: proc(
	dllPathWithoutExtension: string,
	apiVersion: int,
	procedureNamePrefix: string,
) -> (
	api: AppAPI,
	result: bool,
) {
	dllExtension := ".dll"
	dllPath := fmt.tprintf("{0}{1}", dllPathWithoutExtension, dllExtension)
	dllTime, dllTimeError := os.last_write_time_by_name(dllPath)

	if dllTimeError != os.ERROR_NONE {
		fmt.printfln("Could not fetch last write time of {0}", dllPathWithoutExtension)
		return {}, false
	}

	// We cannot load the game DLL directly since it would lock the file and
	// prevent the compiler from writing to it.
	// Instead we will make a copy of the DLL with the version in the name.
	versionedDllPath := fmt.tprintf(
		"{0}_{1}{2}",
		dllPathWithoutExtension,
		apiVersion,
		dllExtension,
	)
	copyResult := copyFile(dllPath, versionedDllPath)
	if !copyResult {
		// If the copy fails, we just return false and do it again next frame.
		//fmt.printfln("Failed to copy {0} to {1}", dllPath, versionedDllPath)
		return {}, false
	}

	copyFile :: proc(srcPath, dstPath: string) -> bool {
		data, ok := os.read_entire_file(srcPath)
		if !ok {
			//fmt.printfln("Failed copy file error: {0}", os.get_last_error())
			return false
		}

		ok = os.write_entire_file(dstPath, data)
		if !ok {
			//fmt.printfln("Failed copy file error: {0}", os.get_last_error())
			return false
		}

		return true
	}

	// This proc call will scan through the symbols in the library and match the symbols to the proc pointers in the provided struct.
	//
	// 'Game_' is the prefix for the symbols in the library.
	// For instance, a procedure in the library named 'Game_Init' will be matched to the field in the struct named 'Init'
	//
	// 'Library' specifies the name of the field in the struct that will be used to hold the library handle,
	// namely `api.Library``
	_, symbolInitResult := dynlib.initialize_symbols(
		&api,
		versionedDllPath,
		procedureNamePrefix,
		"Library",
	)
	if !symbolInitResult {
		fmt.printfln("Failed to initialize symbols from dll: {0}", dynlib.last_error())
		return {}, false
	} else {
		fmt.printfln("Loaded {0}", versionedDllPath)
	}

	api.Info.APIVersion = apiVersion
	api.Info.DLLTimestamp = dllTime
	return api, true
}

UnloadAppAPI :: proc(api: AppAPI) -> (result: bool) {
	// Unload the library
	if api.Library != nil {
		unloadResult := dynlib.unload_library(api.Library)
		if !unloadResult {
			fmt.printfln("Failed to unload lib: {0}", dynlib.last_error())
			return false
		}
	}

	return true
}
