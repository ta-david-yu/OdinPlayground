package main

import "core:c/libc"
import "core:dynlib"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:time"

AppAPI :: struct {
	Info:                 struct {
		DLLTimestamp: time.Time,
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

// Tracking allocator with hot reloading design based on Karl's video: https://youtu.be/dg6qogN8kIE
resetAndPrintTrackingAllocator :: proc(allocator: ^mem.Tracking_Allocator) -> bool {
	err := false
	if len(allocator.allocation_map) > 0 {
		fmt.eprintf("=== %v allocations not freed: ===\n", len(allocator.allocation_map))
		for _, entry in allocator.allocation_map {
			fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
		}
		err = true
	}
	mem.tracking_allocator_clear(allocator)
	return err
}

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)
	}

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

		when ODIN_DEBUG {
			if (len(track.bad_free_array) > 0) {
				for b in track.bad_free_array {
					fmt.eprintf("- Bad free at: %v\n", b.location)
				}

				libc.getchar()
				panic("Bad free detected")
			}
		}


		if api.ShouldExitUpdateLoop() {
			break
		}

		// Check if a hard reset is required
		if api.RequireHardReset() {
			newAPI, newAPIResult := LoadAppAPI(g_LibraryPath, apiVersion, "App_")
			if newAPIResult {
				fmt.printfln("Resetting Application...")
				api.Shutdown()
				when ODIN_DEBUG {
					resetAndPrintTrackingAllocator(&track)
				}

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

	when ODIN_DEBUG {
		if resetAndPrintTrackingAllocator(&track) {
			fmt.eprintln("Enter to continue...")
			libc.getchar()
		}
	}

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
		data, error := os.read_entire_file(srcPath, context.allocator)
		if error != nil {
			return false
		}

		defer delete(data)

		error = os.write_entire_file(dstPath, data)
		if error != nil {
			return false
		}

		return true
	}

	// This proc call will scan through the symbols in the library and match the symbols to the proc pointers in the provided struct.
	//
	// `procedureNamePrefix` is the prefix for the symbols in the library.
	// For instance, a procedure in the library named `${procedureNamePrefix}_Init` will be matched to the field in the struct named 'Init'
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
