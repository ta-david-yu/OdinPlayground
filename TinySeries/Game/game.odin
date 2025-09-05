package game

import "core:c"
import "core:fmt"

GameMemory::struct {
    SomeState: int
}

g_Memory: ^GameMemory

@(export)
Game_Init::proc() {
    g_Memory = new (GameMemory)
}

/* Return false if the game should be shutdown */
@(export)
Game_Update::proc(deltaTime: c.double) -> bool {
    g_Memory.SomeState += 5
    fmt.printfln("HAHA: {0}", g_Memory.SomeState)
    return true
}

@(export)
Game_Shutdown::proc() {
    free(g_Memory)
}

@(export)
Game_GetMemory::proc() -> rawptr {
    return g_Memory
}

/*  
Call this function after the game dll is reloaded.
You should pass in the pointer to the original game memory.
*/
@(export)
Game_OnHotReloaded::proc(gameMemory: ^GameMemory) {
    g_Memory = gameMemory
}
