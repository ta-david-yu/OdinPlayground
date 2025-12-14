package dye

import "core:fmt"

// Value taken from SDL3 MouseButtonFlag (see - sdl3_mouse.odin)
MouseButton :: enum u32 {
	Left   = 1 - 1,
	Middle = 2 - 1,
	Right  = 3 - 1,
}
NUMBER_OF_MOUSE_BUTTONS :: 3

InputText :: struct {
	Buffer: [256]u8,
	Length: int,
}

Input :: struct {
	MouseButtonsPrevFrame: [NUMBER_OF_MOUSE_BUTTONS]bool,
	MouseButtons:          [NUMBER_OF_MOUSE_BUTTONS]bool,
	Text:                  InputText,
}

PushInputTextInBuffer :: proc(input: ^Input, text: cstring) {
	// We first cast the cstring into a string alias for easier operation.
	textAsStr := cast(string)text
	input.Text.Length = copy(input.Text.Buffer[:], textAsStr)
}

UpdateInputEndOfFrame :: proc(input: ^Input) {
	// Expire input states
	for i := 0; i < NUMBER_OF_MOUSE_BUTTONS; i += 1 {
		input.MouseButtonsPrevFrame[i] = input.MouseButtons[i]
	}

	input.Text.Length = 0
}

IsMouseButton :: proc(input: ^Input, button: MouseButton) -> bool {
	return input.MouseButtons[button]
}

IsMouseButtonDown :: proc(input: ^Input, button: MouseButton) -> bool {
	return !input.MouseButtonsPrevFrame[button] && input.MouseButtons[button]
}

IsMouseButtonUp :: proc(input: ^Input, button: MouseButton) -> bool {
	return input.MouseButtonsPrevFrame[button] && !input.MouseButtons[button]
}
