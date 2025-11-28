# Project

## Package Structure

- [x] main (exe) -> game (dll) -> dye (static library)
- [x] Since dye uses vendor libraries (i.e., sdl3, sdl3/ttf), they need to be linked dynamically (dlls)
- [x] dye has a memory struct type and functions to create and free a memory object
- [x] dygui also has a context struct type and functions to create and free a context object
- [ ] api should have the option to reset the whole memory, reload the whole app.

# DYGUI

## Widget

- [] Slider
- [] Checkbox
- [] Image (Texture System)

## Layout

- [] FixedSizeContainer
- [] VerticalLayoutContainer
- [] HorizontalLayoutContainer
- [] Dummy

## Animation System

### Targets

- [] Position
- [] Color
- [] Size

### Duration & Value

- [] Time
- [] Easing Function(s)

### Events:

- [] OnAppear
- [] OnDisappear
- [] Manual Trigger (PlayAnimationOnNextItem)

## Other Stuff

- [] Having a global context, avoid global function
