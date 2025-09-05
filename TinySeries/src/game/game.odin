package game

import "core:c"
import "core:fmt"
import rl "vendor:raylib"

GameMemory::struct {
    SomeState: int
}

g_Memory: ^GameMemory

@(export)
Game_Init::proc() {
    rl.SetConfigFlags({ .WINDOW_RESIZABLE })
    rl.InitWindow(800, 800, "Odin Tiny Series")
    rl.SetTargetFPS(60)

    g_Memory = new (GameMemory)
}

@(export)
Game_RequireReset::proc() -> bool {
    return false    
}

/* Return false if the game should be shutdown */
@(export)
Game_Update::proc() -> bool {
    g_Memory.SomeState += 1
    rl.BeginDrawing()
    {
        deltaTime := rl.GetFrameTime()
    }
    rl.EndDrawing()
    return true
}

@(export)
Game_Shutdown::proc() {
    free(g_Memory)
    rl.CloseWindow()
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
