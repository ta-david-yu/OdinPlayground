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
	RequireHardReset:     proc() -> bool,
	Init:                 proc(),
	OneLoop:              proc(),
	HotReload:            proc(appMemory: rawptr),
	Shutdown:             proc(),
}

g_Api: AppAPI = {}

g_LibraryExtension :: ".dll"
g_LibraryPath :: "app"


main :: proc() {
	apiVersion := 0
	api, result := LoadAppAPI(g_LibraryPath, apiVersion, "App_")
	if !result {
		fmt.printfln("Failed to load dll file.")
		return
	}
	apiVersion += 1

	api.Init()

	fmt.printfln("Loop with api version {0}", api.Info.APIVersion)

	counter := 0
	for {
		api.OneLoop()
		if api.ShouldExitUpdateLoop() {
			break
		}

		// Check if a hard reset is required
		if api.RequireHardReset() {
			newAPI, newAPIResult := LoadAppAPI(g_LibraryPath, apiVersion, "App_")
			if newAPIResult {
				fmt.printfln("Resetting Application...")

				api.Shutdown()

				// Unload the old library
				if UnloadAppAPI(api) {
					dllPathToRemove := fmt.tprintf(
						"{0}_{1}{2}",
						g_LibraryPath,
						api.Info.APIVersion,
						g_LibraryExtension,
					)
					removeError := os.remove(dllPathToRemove)
					if removeError != os.ERROR_NONE {
						fmt.printfln("Failed to remove {0}: {1}", dllPathToRemove, removeError)
					}
				}

				// Replace the api with the new loaded instance
				api = newAPI

				api.Init()

				apiVersion += 1
				continue
			}
		}

		// Check if the dll has a new update
		dllPath := fmt.tprintf("{0}{1}", g_LibraryPath, g_LibraryExtension)
		dllTime, dllTimeError := os.last_write_time_by_name(dllPath)
		shouldReload: bool = dllTimeError == os.ERROR_NONE && api.Info.DLLTimestamp != dllTime
		if shouldReload {
			newAPI, newAPIResult := LoadAppAPI(g_LibraryPath, apiVersion, "App_")
			if newAPIResult {
				// Cache the address to the game memory
				existingGameMemory: rawptr = api.GetAppMemory()

				// Unload the old library
				if UnloadAppAPI(api) {
					dllPathToRemove := fmt.tprintf(
						"{0}_{1}{2}",
						g_LibraryPath,
						api.Info.APIVersion,
						g_LibraryExtension,
					)
					removeError := os.remove(dllPathToRemove)
					if removeError != os.ERROR_NONE {
						fmt.printfln("Failed to remove {0}: {1}", dllPathToRemove, removeError)
					}
				}

				// Replace the api with the new loaded instance
				api = newAPI

				// Set the address to the mmoery back
				api.HotReload(existingGameMemory)

				apiVersion += 1
				continue
			}
		}
	}

	api.Shutdown()
	if UnloadAppAPI(api) {
		dllPathToRemove := fmt.tprintf(
			"{0}_{1}{2}",
			g_LibraryPath,
			api.Info.APIVersion,
			g_LibraryExtension,
		)
		removeError := os.remove(dllPathToRemove)
	}
}


LoadAppAPI :: proc(
	dllPathWithoutExtension: string,
	apiVersion: int,
	procedureNamePrefix: string,
) -> (
	api: AppAPI,
	result: bool,
) {
	dllPath := fmt.tprintf("{0}{1}", dllPathWithoutExtension, g_LibraryExtension)
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
		g_LibraryExtension,
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
			return false
		}

		ok = os.write_entire_file(dstPath, data)
		if !ok {
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

	fmt.printfln("Unload lib of version {0}", api.Info.APIVersion)
	return true
}
