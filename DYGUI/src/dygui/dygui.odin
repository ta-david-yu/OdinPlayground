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

NextItemDataFlag :: enum
{
    HasSize = 0,
}

NextItemData :: struct 
{
    Flags: bit_set[NextItemDataFlag],
    Size: [2]f32,
}

TextDrawData :: struct
{
    TextRect: Rect,
    TextContent: string,
    TextColor: [4]u8,
    FontConfig: FontConfig
}

CornerRadius :: struct 
{
    TL: f32,
    TR: f32,
    BR: f32,
    BL: f32
}

FilledRectangleDrawData :: struct 
{
    Rect: Rect,
    Color: [4]u8,
    CornerRadius: CornerRadius
}

RectangleDrawData :: struct
{
    Rect: Rect,
    Color: [4]u8,
    CornerRadius: CornerRadius,
    Thickness: f32
}

DrawData :: union 
{
    TextDrawData,
    FilledRectangleDrawData,
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
        Shadow : [4]u8,
        Text : [4]u8,
        Button : struct 
        {
            Idle : [4]u8,
            Hovered : [4]u8,
            Active : [4]u8,
            
            InnerBorderIdle : [4]u8,
            InnerBorderHovered : [4]u8,
            InnerBorderActive : [4]u8,
            
            OuterBorderIdle : [4]u8,
            OuterBorderHovered : [4]u8,
            OuterBorderActive : [4]u8,
        }
    },

    Variables : struct
    {
        Shadow : struct 
        {
            Offset : [2]f32,
            Softness : u8
        },
        Button : struct 
        {
            FramePaddingTop : f32,
            FramePaddingBottom : f32,
            FramePaddingLeft : f32,
            FramePaddingRight : f32,
            CornerRadius : CornerRadius,
            InnerBorderThickness : u8,
            OuterBorderThickness : u8
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
    State: State,

    // Next item / widget data
    NextItemData: NextItemData,
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
    // Setup UI global state
    state := GetState()
    if (state.ActiveId == id)
    {
        state.ActiveIdIsAlive = id
    }
    state.LastItemData.Id = id
    state.LastItemData.Rect = rect

    // Clear next item data & flags
    guiContext := GetGUIContext()
    guiContext.NextItemData.Flags = {}
}

SetMainFontConfig :: proc(fontConfig: FontConfig)
{
    GetGUIContext().Style.MainFontConfig = fontConfig
}

PushFontConfig :: proc(fontConfig: FontConfig)
{
    currentFontConfig := GetStyle().MainFontConfig
    append(&GetGUIContext().Style.FontConfigStack, currentFontConfig)
    GetStyle().MainFontConfig = fontConfig
}

PopFontConfig :: proc(count: int = 1)
{
    style := GetStyle()
    for i := 0; i < count; i += 1
    {
        style.MainFontConfig = pop(&style.FontConfigStack)
    }
}

IsItemHovered :: proc() -> bool
{
    state := GetState()
    return state.HoveredId == state.LastItemData.Id
}

// Set the size of the next item. 
// You can use 0 to indicate auto fit at the specified dimension.
// For instance, if next item size is set to {400, 0}, the width will be 400 but the height will be automatically calculated based on the content of the item. 
SetNexItemSize :: proc(size: [2]f32)
{
    guiContext := GetGUIContext()
    guiContext.NextItemData.Flags += { .HasSize }
    guiContext.NextItemData.Size = size
}

GetLastItemRect :: proc() -> Rect
{
    state := GetState()
    return state.LastItemData.Rect
}

Button :: proc(label: string, position: [2]f32) -> bool
{
    id : DYID = getID(label)

    style := GetStyle()
    state := GetState()

    isClicked : bool = false;
    
    guiContext := GetGUIContext()
    fontConfig := style.MainFontConfig

    textDimensions := guiContext.Functions.MeasureText(label, fontConfig)
    textRect : Rect
    fullRect : Rect

    xPadding := style.Variables.Button.FramePaddingLeft + style.Variables.Button.FramePaddingRight
    yPadding := style.Variables.Button.FramePaddingTop + style.Variables.Button.FramePaddingBottom
    if (NextItemDataFlag.HasSize in guiContext.NextItemData.Flags)
    {
        // If next item size flag is set, we use the size data directly; ignoring frame padding.
        useFixedWidth : bool = guiContext.NextItemData.Size.x > 0
        useFixedHeight : bool = guiContext.NextItemData.Size.y > 0

        fullRectWidth := useFixedWidth? guiContext.NextItemData.Size.x : textDimensions.x + xPadding
        fullRectHeight := useFixedHeight? guiContext.NextItemData.Size.y : textDimensions.y + yPadding
        fullRect = Rect{Position=position, Size={fullRectWidth, fullRectHeight}}

        // At the moment we align text to the center middle.
        xTextRect := position.x + (useFixedWidth? fullRect.Size.x * 0.5 - textDimensions.x * 0.5 : style.Variables.Button.FramePaddingLeft)
        yTextRect := position.y + (useFixedHeight? fullRect.Size.y * 0.5 - textDimensions.y * 0.5 : style.Variables.Button.FramePaddingTop)
        textRect = Rect{Position={xTextRect, yTextRect}, Size=textDimensions.xy}
    }
    else
    {
        // If the size is not provided, we will use the text dimension to calculate the button size.
        fullRect = Rect{Position=position, Size=textDimensions.xy + {xPadding, yPadding}}
        textRect = Rect{Position=position + {style.Variables.Button.FramePaddingLeft, style.Variables.Button.FramePaddingTop}, Size=textDimensions.xy}
    }
    addItem(fullRect, id)

    mouseButton : u8 = 0

    // Handle the case where the user pointer is within the hoverable rect
    pointerRect := fullRect
    if (style.Variables.Button.OuterBorderThickness > 0)
    {
        pointerRect.Position -= cast(f32) style.Variables.Button.OuterBorderThickness
        pointerRect.Size += cast(f32) style.Variables.Button.OuterBorderThickness * 2
    }

    isHovered: bool = isPointInRect(state.InputState.MousePosition, pointerRect)
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
    innerBorderColor : [4]u8 = style.Colors.Button.InnerBorderIdle
    outerBorderColor : [4]u8 = style.Colors.Button.OuterBorderIdle
    if (isHovered) 
    {
        if (state.ActiveId == id) 
        {
            backgroundColor = style.Colors.Button.Active
            innerBorderColor = style.Colors.Button.InnerBorderActive
            outerBorderColor = style.Colors.Button.OuterBorderActive
        }
        else 
        {
            backgroundColor = style.Colors.Button.Hovered
            innerBorderColor = style.Colors.Button.InnerBorderHovered
            outerBorderColor = style.Colors.Button.OuterBorderHovered
        }
    }

    cornerRadius := style.Variables.Button.CornerRadius

    // Shadow
    if (style.Variables.Shadow.Offset.x > 0 || style.Variables.Shadow.Offset.y > 0)
    {
        hardShadow : bool = style.Variables.Shadow.Softness == 0 
        if (hardShadow)
        {
            shadowRect := fullRect
            shadowRect.Position += style.Variables.Shadow.Offset 
            addCommandToFrame(FilledRectangleDrawData { Rect = shadowRect, Color = style.Colors.Shadow, CornerRadius = cornerRadius }, &state.Frame)
        }
        else // We use multiple layered transparent rectangles to achieve shadow 
        {
            mainShadowRect := fullRect
            mainShadowRect.Position += style.Variables.Shadow.Offset 

            layerColor := style.Colors.Shadow
            layerColor /= style.Variables.Shadow.Softness
            for i : u8 = 0; i < style.Variables.Shadow.Softness; i += 1
            {
                shadowLayerRect := mainShadowRect
                shadowLayerRect.Position += cast(f32) i
                shadowLayerRect.Size -= cast(f32) i * 2 
                addCommandToFrame(FilledRectangleDrawData { Rect = shadowLayerRect, Color = layerColor * i, CornerRadius = cornerRadius }, &state.Frame)
            }
        }
    }

    // Background & Border if needed
    if (style.Variables.Button.InnerBorderThickness == 0 && style.Variables.Button.OuterBorderThickness == 0)
    {
        backgroundRect := fullRect
        addCommandToFrame(FilledRectangleDrawData { Rect = backgroundRect, Color = backgroundColor, CornerRadius = cornerRadius }, &state.Frame)
    }
    else 
    {
        backgroundRect := fullRect
        addCommandToFrame(FilledRectangleDrawData { Rect = backgroundRect, Color = backgroundColor, CornerRadius = cornerRadius }, &state.Frame)

        if (style.Variables.Button.OuterBorderThickness > 0)
        {
            outerBorderRect := fullRect
            outerBorderRect.Position -= cast(f32) style.Variables.Button.OuterBorderThickness
            outerBorderRect.Size += cast(f32) style.Variables.Button.OuterBorderThickness * 2
            addCommandToFrame(
                RectangleDrawData { 
                    Rect = outerBorderRect,
                    Color = outerBorderColor, 
                    CornerRadius = cornerRadius, 
                    Thickness = cast(f32) style.Variables.Button.OuterBorderThickness 
                }, 
                &state.Frame
            )
        }

        if (style.Variables.Button.InnerBorderThickness > 0)
        {
            innerBorderRect := fullRect
            addCommandToFrame(
                RectangleDrawData { 
                    Rect = innerBorderRect,
                    Color = innerBorderColor, 
                    CornerRadius = cornerRadius, 
                    Thickness = cast(f32) style.Variables.Button.InnerBorderThickness 
                }, 
                &state.Frame
            )
            //addCommandToFrame(FilledRectangleDrawData { Rect = innerBorderRect, Color = innerBorderColor, CornerRadius = cornerRadius }, &state.Frame)
        }
    }

    // Text
    addCommandToFrame(TextDrawData { TextRect = textRect, TextColor = style.Colors.Text, TextContent = label, FontConfig = fontConfig }, &state.Frame)

    return isClicked
}

Text :: proc(label: string, position: [2]f32)
{
    id : DYID = getID(label)

    style := GetStyle()
    state := GetState()

    guiContext := GetGUIContext()
    fontConfig := style.MainFontConfig

    textDimensions := guiContext.Functions.MeasureText(label, fontConfig)
    textRect : Rect
    fullRect : Rect
    
    if (NextItemDataFlag.HasSize in guiContext.NextItemData.Flags)
    {
        // If next item size flag is set, we use the size data directly; ignoring frame padding.
        useFixedWidth : bool = guiContext.NextItemData.Size.x > 0
        useFixedHeight : bool = guiContext.NextItemData.Size.y > 0

        fullRectWidth := useFixedWidth? guiContext.NextItemData.Size.x : textDimensions.x
        fullRectHeight := useFixedHeight? guiContext.NextItemData.Size.y : textDimensions.y
        fullRect = Rect{Position=position, Size={fullRectWidth, fullRectHeight}}

        // At the moment we align text to the center middle.
        xTextRect := position.x + (useFixedWidth? fullRect.Size.x * 0.5 - textDimensions.x * 0.5 : 0)
        yTextRect := position.y + (useFixedHeight? fullRect.Size.y * 0.5 - textDimensions.y * 0.5 : 0)
        textRect = Rect{Position={xTextRect, yTextRect}, Size=textDimensions.xy}
    }
    else
    {
        // If the size is not provided, we will use the text dimension directly
        fullRect = Rect{Position=position, Size=textDimensions.xy}
        textRect = fullRect
    }
    addItem(fullRect, id)

    
    // Text
    addCommandToFrame(TextDrawData { TextRect = textRect, TextColor = style.Colors.Text, TextContent = label, FontConfig = fontConfig }, &state.Frame)
}