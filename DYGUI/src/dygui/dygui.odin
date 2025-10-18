package dygui

import "core:hash"
import "core:fmt"

NUMBER_OF_MOUSE_BUTTONS :: 5

Rect :: struct 
{
    Position: [2]f32,
    Size: [2]f32
}

State :: struct 
{
    Canvas: Canvas,
    InputState: InputState,
    Frame: Frame,

    ActiveId: u32,
    IsActiveIdJustActivated: bool,
    ActiveIdIsAlive: u32,
    ActiveIdPreviousFrame: u32
}

g_State: State

Canvas :: struct 
{
    Width: f32,
    Height: f32,
}

InputState :: struct 
{
    MouseButtons: [NUMBER_OF_MOUSE_BUTTONS]bool,
    LastMouseButtons: [NUMBER_OF_MOUSE_BUTTONS]bool,
    
    MousePosition: [2]f32
}

Frame :: struct 
{
    NumberOfButtons: int,
    Buttons: [dynamic]ButtonData
}

ButtonData :: struct 
{
    Rect: Rect,
    Color: [4]u8
}

GetState :: proc() -> ^State 
{
    return &g_State;
}

GetInputState :: proc() -> ^InputState 
{
    return &g_State.InputState
}

@(private)
wasMouseButtonDownThisFrame :: proc(mouseButton: u8) -> bool 
{
    return g_State.InputState.MouseButtons[mouseButton] && !g_State.InputState.LastMouseButtons[mouseButton] 
}

@(private)
wasMouseButtonUpThisFrame :: proc(mouseButton: u8) -> bool 
{
    return !g_State.InputState.MouseButtons[mouseButton] && g_State.InputState.LastMouseButtons[mouseButton] 
}

@(private)
isMouseButtonDown :: proc(mouseButton: u8) -> bool 
{
    return g_State.InputState.MouseButtons[mouseButton]
}

Init :: proc(canvas: Canvas) 
{
    g_State.Canvas = canvas
}

NewFrame :: proc() 
{
    state := GetState()
    state.Frame.NumberOfButtons = 0

    if (state.ActiveId != 0 && state.ActiveIdIsAlive != state.ActiveId && state.ActiveIdPreviousFrame == state.ActiveId) 
    {
        clearActiveId()
    }

    state.ActiveIdPreviousFrame = state.ActiveId 
    state.ActiveIdIsAlive = 0
    state.IsActiveIdJustActivated = false
}

EndFrame :: proc() 
{
    state := GetState()

    // Expire input states
    for i := 0; i < NUMBER_OF_MOUSE_BUTTONS; i += 1 
    {
        state.InputState.LastMouseButtons[i] = state.InputState.MouseButtons[i]
    }
}

Render :: proc() 
{
    // TODO: compile a draw list with z sorting?
}

@(private)
isPointInRect :: proc(point: [2]f32, rect: Rect) -> bool 
{
    x_min := rect.Position[0];
    y_min := rect.Position[1];
    x_max := x_min + rect.Size[0];
    y_max := y_min + rect.Size[1];

    return point[0] >= x_min && point[0] <= x_max &&
           point[1] >= y_min && point[1] <= y_max;
}

@(private)
setActiveId :: proc(id: u32) 
{
    state := GetState()
    if (state.ActiveId != 0) 
    {
        // TODO: Clear previously active widget state
    }

    state.IsActiveIdJustActivated = state.ActiveId != id
    if (state.IsActiveIdJustActivated) 
    {
        // TODO: logic to check if the item has just been activated
    }
    
    state.ActiveId = id;
    if (id != 0) 
    {
        state.ActiveIdIsAlive = id
    }
}

@(private)
clearActiveId :: proc() 
{
    GetState().ActiveId = 0
}

Button :: proc(label: string, position: [2]f32, size: [2]f32, color: [4]u8) -> bool 
{
    isClicked : bool = false;

    id : u32 = hash.crc32(transmute([]byte) label)
    
    state := GetState()
    
    if (state.Frame.NumberOfButtons >= len(state.Frame.Buttons)) 
    {
        append(&state.Frame.Buttons, ButtonData {})
    }

    rect := Rect{Position=position, Size=size}
    button : ^ButtonData = &state.Frame.Buttons[state.Frame.NumberOfButtons]    
    state.Frame.NumberOfButtons += 1

    // Mark the button id as alive if it was already the active id last frame
    if (state.ActiveId == id)
    {
        state.ActiveIdIsAlive = id
    }

    mouseButton : u8 = 0
    // Handle the case where the user pointer is within the hoverable rect
    isHovered: bool = isPointInRect(state.InputState.MousePosition, rect)
    if (isHovered) 
    {
        isMouseDown := wasMouseButtonDownThisFrame(mouseButton)
        if (isMouseDown) 
        {
            setActiveId(id)
        }

        isMouseUp := wasMouseButtonUpThisFrame(mouseButton)
        if (isMouseUp) 
        {
            isClicked = true
            clearActiveId()
        }
    }
    
    // Handle the case where the user has pressed down on the button but haven't released it yet.
    if (state.ActiveId == id) 
    {
        if (isMouseButtonDown(mouseButton)) 
        {
            // TODO: the user is still holding the button
        }  
        else 
        {
            //clearActiveId()
        }
    }

    // Set color based on the state
    button.Rect = rect
    if (isHovered) 
    {
        if (state.ActiveId == id) 
        {
            button.Color.rgba = { 120, 120, 120, 255 }
        }
        else 
        {
            button.Color.rgba = { 255, 255, 255, 255 }
        }
    } 
    else 
    {
        button.Color.rgba = color
    }

    return isClicked
}