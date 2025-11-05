package dygui

import "core:hash"

NUMBER_OF_MOUSE_BUTTONS :: 5

DYID :: distinct u32

Dimensions :: distinct [2]f32

Rect :: struct 
{
    Position: [2]f32,
    Size: [2]f32
}

TextDrawData :: struct
{
    TextRect: Rect,
    TextContent: string,
    TextColor: [4]u8,
    FontConfig: FontConfig
}

RectangleDrawData :: struct 
{
    Rect: Rect,
    Color: [4]u8
}

DrawData :: union 
{
    TextDrawData,
    RectangleDrawData
}

DrawCommand :: struct
{
    Data: DrawData,
}

DrawFrame :: struct 
{
    NumberOfDrawCommands: int,
    DrawCommands: [dynamic]DrawCommand
}

addCommandToFrame :: proc (drawData: DrawData, frame: ^DrawFrame)
{
    command : DrawCommand
    command.Data = drawData

    if (frame.NumberOfDrawCommands >= len(frame.DrawCommands))
    {
        append(&frame.DrawCommands, command)
    }
    else
    {
        frame.DrawCommands[frame.NumberOfDrawCommands] = command
    }

    frame.NumberOfDrawCommands += 1;
}

FontConfig :: struct 
{
    FontId: u16,
    FontSize: u16
}

Style :: struct
{

    MainFontConfig : FontConfig,
    FontConfigStack : [dynamic]FontConfig,

    Colors : struct 
    {
        Button : struct 
        {
            Idle : [4]u8,
            Hovered : [4]u8,
            Active : [4]u8,
            Text : [4]u8
        }
    },

    Variables : struct
    {
        Button : struct 
        {
            FramePaddingTop : f32,
            FramePaddingBottom : f32,
            FramePaddingLeft : f32,
            FramePaddingRight : f32,
        }
    }
}

State :: struct 
{
    InputState: InputState,
    Frame: DrawFrame,

    ActiveId: DYID,
    IsActiveIdJustActivated: bool,
    ActiveIdIsAlive: DYID,
    ActiveIdPreviousFrame: DYID,

    HoveredId: DYID,

    LastItemData: LastItemData,
}

Functions :: struct 
{
    MeasureText: proc(textContent: string, fontConfig: FontConfig) -> Dimensions
}

GUIContext :: struct
{
    Canvas: Canvas,
    Style: Style,
    Functions: Functions,
    State: State
}

g_Context: GUIContext

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

LastItemData :: struct 
{
    Id: DYID,
    Rect: Rect
}

ButtonData :: struct 
{
    Rect: Rect,
    Color: [4]u8
}

GetGUIContext :: proc() -> ^GUIContext
{
    return &g_Context
}

GetState :: proc() -> ^State 
{
    return &g_Context.State
}

GetStyle :: proc() -> ^Style
{
    return &g_Context.Style
}

GetInputState :: proc() -> ^InputState 
{
    return &g_Context.State.InputState
}

@(private)
wasMouseButtonDownThisFrame :: proc(mouseButton: u8) -> bool 
{
    inputState := GetInputState()
    return inputState.MouseButtons[mouseButton] && !inputState.LastMouseButtons[mouseButton] 
}

@(private)
wasMouseButtonUpThisFrame :: proc(mouseButton: u8) -> bool 
{
    inputState := GetInputState()
    return !inputState.MouseButtons[mouseButton] && inputState.LastMouseButtons[mouseButton] 
}

@(private)
isMouseButtonDown :: proc(mouseButton: u8) -> bool 
{
    inputState := GetInputState()
    return inputState.MouseButtons[mouseButton]
}

@(private)
getID :: proc(label: string) -> DYID 
{
    return cast(DYID) hash.crc32(transmute([]byte) label)
}

Init :: proc(canvas: Canvas) 
{
    g_Context.Canvas = canvas
}

SetMeasureTextFunction :: proc(func: proc(textContent: string, fontConfig: FontConfig) -> Dimensions)
{
    g_Context.Functions.MeasureText = func
}

NewFrame :: proc() 
{
    state := GetState()
    
    // Clear button states
    state.Frame.NumberOfDrawCommands = 0

    // Clear last item data states
    state.LastItemData.Id = 0
    state.LastItemData.Rect = {}

    // Clear hover states
    state.HoveredId = 0

    // Clear active states
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
setActiveId :: proc(id: DYID) 
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

@(private)
setHoveredId :: proc(id: DYID)
{
    state := GetState()
    state.HoveredId = id
}

@(private)
addItem :: proc(rect: Rect, id: DYID) 
{    
    state := GetState()
    if (state.ActiveId == id)
    {
        state.ActiveIdIsAlive = id
    }
    state.LastItemData.Id = id
    state.LastItemData.Rect = rect
}

SetMainFontConfig :: proc(fontConfig: FontConfig)
{
    GetGUIContext().Style.MainFontConfig = fontConfig
}

PushFontConfig :: proc(fontConfig: FontConfig)
{
    append(&GetGUIContext().Style.FontConfigStack, fontConfig)
}

PopFontConfig :: proc(count: int = 1)
{
    state := GetState()
    for i := 0; i < count; i += 1
    {
        pop(&GetGUIContext().Style.FontConfigStack)
    }
}

getCurrentFontConfig :: proc() -> FontConfig
{
    guiContext := GetGUIContext()
    length := len(guiContext.Style.FontConfigStack)
    if (length > 0)
    {
        return guiContext.Style.FontConfigStack[length - 1]
    }
    else 
    {
        return guiContext.Style.MainFontConfig
    }
}

IsItemHovered :: proc() -> bool
{
    state := GetState()
    return state.HoveredId == state.LastItemData.Id
}

ColorButton :: proc(label: string, position: [2]f32, size: [2]f32, color: [4]u8) -> bool 
{
    state := GetState()

    isClicked : bool = false;
    id : DYID = getID(label)
    
    rect := Rect{Position=position, Size=size}
    finalColor : [4]u8 = color

    addItem(rect, id)

    mouseButton : u8 = 0
    // Handle the case where the user pointer is within the hoverable rect
    isHovered: bool = isPointInRect(state.InputState.MousePosition, rect)
    if (isHovered) 
    {
        setHoveredId(id)

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
            clearActiveId()
        }
    }

    // Set color based on the state
    if (isHovered) 
    {
        if (state.ActiveId == id) 
        {
            finalColor = { 120, 120, 120, 255 }
        }
        else 
        {
            finalColor = { 255, 255, 255, 255 }
        }
    }

    addCommandToFrame(RectangleDrawData { Rect = rect, Color = finalColor }, &state.Frame)

    return isClicked
}

Button :: proc(label: string, position: [2]f32) -> bool
{
    style := GetStyle()
    state := GetState()

    isClicked : bool = false;
    id : DYID = getID(label)
    
    guiContext := GetGUIContext()
    fontConfig := getCurrentFontConfig()
    textDimensions := guiContext.Functions.MeasureText(label, fontConfig)

    xPadding := style.Variables.Button.FramePaddingLeft + style.Variables.Button.FramePaddingRight
    yPadding := style.Variables.Button.FramePaddingTop + style.Variables.Button.FramePaddingBottom

    textRect := Rect{Position=position + {style.Variables.Button.FramePaddingLeft, style.Variables.Button.FramePaddingTop}, Size=textDimensions.xy}
    fullRect := Rect{Position=position, Size=textDimensions.xy + {xPadding, yPadding}}
    addItem(fullRect, id)

    mouseButton : u8 = 0

    // Handle the case where the user pointer is within the hoverable rect
    isHovered: bool = isPointInRect(state.InputState.MousePosition, fullRect)
    if (isHovered) 
    {
        setHoveredId(id)

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
            clearActiveId()
        }
    }

    // Set color based on the state
    backgroundColor : [4]u8 = style.Colors.Button.Idle
    if (isHovered) 
    {
        if (state.ActiveId == id) 
        {
            backgroundColor = style.Colors.Button.Active
        }
        else 
        {
            backgroundColor = style.Colors.Button.Hovered
        }
    }

    addCommandToFrame(RectangleDrawData { Rect = fullRect, Color = backgroundColor }, &state.Frame)
    addCommandToFrame(TextDrawData { TextRect = textRect, TextColor = style.Colors.Button.Text, TextContent = label, FontConfig = fontConfig }, &state.Frame)

    return isClicked
}