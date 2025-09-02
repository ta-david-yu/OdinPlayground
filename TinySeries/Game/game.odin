package game

import "core:fmt"

GameMemory::struct {
    SomeState: int
}

g_Memory: ^GameMemory

@(export)
InitGame::proc() {
    g_Memory = new (GameMemory)
}

/* Return false if the game should be shutdown */
@(export)
UpdateGame::proc(deltaTime: f64) -> bool {
    g_Memory.SomeState += 1
    fmt.println(g_Memory.SomeState)
    return true
}

@(export)
ShutdownGame::proc() {
    free(g_Memory)
}

@(export)
GetGameMemory::proc() -> rawptr {
    return g_Memory
}

/*  
Call this function after the game dll is reloaded.
You should pass in the pointer to the original game memory.
*/
@(export)
HotReloadGame::proc(gameMemory: ^GameMemory) {
    g_Memory = gameMemory
}
