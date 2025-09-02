package main

import "core:c/libc"
import "core:c"
import "core:fmt"
import "core:os"
import "core:dynlib"

GameAPI::struct {
    Init: proc(),
    Update: proc(deltaTime: c.double) -> bool,
    Shutdown: proc(),
    GetMemory: proc() -> rawptr,
    OnHotReloaded: proc(rawptr),

    Library: dynlib.Library,
    DLLTimestamp: os.File_Time,
    APIVersion: int
}

LoadGameAPI::proc(dllPath: string, apiVersion: int) -> (api: GameAPI, result: bool) {
    dllTime, dllTimeError := os.last_write_time_by_name(dllPath)

    if dllTimeError != os.ERROR_NONE {
        fmt.printfln("Could not fetch last write time of {0}", dllPath)
        return {}, false
    }

    // We cannot load the game DLL directly since it would lock the file and
    // prevent the compiler from writing to it.
    // Instead we will make a copy of the DLL with the version in the name.
    copyDLLPath := fmt.tprintf("game_{0}.dll", apiVersion)
    copyResult := copyFile(dllPath, copyDLLPath)
    if !copyResult {
        // If the copy fails, we just return false and do it again next frame.
        fmt.printfln("Failed to copy {0} to {1}", dllPath, copyDLLPath)
        return {}, false
    }

    copyFile::proc(srcPath, dstPath: string) -> bool {
        data, ok := os.read_entire_file(srcPath)
        if !ok {
            fmt.printfln("Failed copy file error: {0}", os.get_last_error())
            return false
        }

        ok = os.write_entire_file(dstPath, data)
        if !ok {
            fmt.printfln("Failed copy file error: {0}", os.get_last_error())
            return false
        }

        return true
    }

    // Load the copied game DLL
    library, libraryResult := dynlib.load_library(copyDLLPath)
    if !libraryResult {
        fmt.printfln("Failed to load DLL at {0}", copyDLLPath)
        return {}, false
    }

    // This proc call will scan through the symbols in the library and match the symbols to the proc pointers in the provided struct.
    //
    // 'Game_' is the prefix for the symbols in the library.
    // For instance, a procedure in the library named 'Game_Init' will be matched to the field in the struct named 'Init'
    //
    // 'Library' specifies the name of the field in the struct that will be used to hold the library handle,
    // namely `api.Library``
    _, symbolInitResult := dynlib.initialize_symbols(&api, copyDLLPath, "Game_", "Library")
    if !symbolInitResult {
		fmt.printfln("Failed to initialize symbols: {0}", dynlib.last_error())
        return {}, false
    }

    api.APIVersion = apiVersion
    api.DLLTimestamp = dllTime
    return api, true
}

/* Return the path to the unloaded library. */
UnloadGameAPI::proc(api: GameAPI) -> string {
    // Unload the library
    if api.Library != nil {
        if !dynlib.unload_library(api.Library) {
			fmt.printfln("Failed to unload lib: {0}", dynlib.last_error())
        }
    }

    return fmt.tprintf("game_{0}.dll", api.APIVersion)
}

GAME_DLL_PATH :: "Game/game.dll"

main::proc() {
    gameAPIVersion := 0
    gameAPI, gameAPIResult := LoadGameAPI(GAME_DLL_PATH, gameAPIVersion)

    if !gameAPIResult {
        fmt.println("Failed to load Game API")
        return
    }

    gameAPIVersion += 1
    gameAPI.Init()

    pathsToLibrariesToRemove: [dynamic] string

    for {
        if (len(pathsToLibrariesToRemove) > 0) {
            #reverse for libraryPath in pathsToLibrariesToRemove {
                // Delete the copied game.dll
                removeError := os.remove(libraryPath)
                if removeError != os.ERROR_NONE {
                    //fmt.printfln("Failed to remove {0}: {1}", libraryPath, removeError)
                }
                else {
                    // If succesfully removed, pop it from the list
                    pop(&pathsToLibrariesToRemove)
                }
            }
        }

        if gameAPI.Update(0) == false {
            break
        }

        // Check if the dll has a new update
        dllTime, dllTimeError := os.last_write_time_by_name(GAME_DLL_PATH)
        shouldReload : bool = dllTimeError == os.ERROR_NONE && gameAPI.DLLTimestamp != dllTime
        if !shouldReload {
            continue
        }

        newAPI, newAPIResult := LoadGameAPI(GAME_DLL_PATH, gameAPIVersion)
        if newAPIResult {
            // Cache the address to the game memory
            existingGameMemory : rawptr = gameAPI.GetMemory()
            
            // Unload the old library
            libraryToRemove := UnloadGameAPI(gameAPI)
            if (len(libraryToRemove) != 0) {
                append(&pathsToLibrariesToRemove, libraryToRemove)
            }

            // Replace the api with the new loaded instance
            gameAPI = newAPI

            // Set the address to the mmoery back
            gameAPI.OnHotReloaded(existingGameMemory)

            gameAPIVersion += 1
        }
    }

    fmt.println("Shutting down...")
    gameAPI.Shutdown()
    libraryPath := UnloadGameAPI(gameAPI)
    removeError := os.remove(libraryPath)
}