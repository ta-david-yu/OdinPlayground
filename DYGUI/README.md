# Getting Started

Odin version: [dev-2026-05](https://github.com/odin-lang/Odin/releases/tag/dev-2026-05)

## Build

The project has hot-reloading support. The actual game/app logic is built as dll and the main.exe loads the dll dynamically.

To simply build and run the project, do the following in the command line:

1. Run `./scripts/app-dll-build.bat` to build the `app.dll`.
2. Run `./scripts/main-exe-build-and-run.bat` to build the executable and run it. Note that this script also copies the necessary extern dlls and assets into the output folder.
3. When the `main.exe` is running, you can trigger the first step as many time as you wanted to hot-reload your app logic.

To automatically watch any changes on the files that contributes to `app.dll` and rebuild it:

1. Run `./scripts/builder-exe-build-and-run.bat` to build the `builder.exe` and run it. `builder.exe` watches any changes on the relevant files and build new `app.dll` when needed.
2. Run `./scripts/main-exe-build-and-run.bat` to build the executable and run it. Note that this script also copies the necessary extern dlls and assets into the output folder.

## Shader Compilation

Based on https://hamdy-elzanqali.medium.com/let-there-be-triangles-sdl-gpu-edition-bd82cf2ef615

1. Install Vulkan SDK (version 1.4.350.0 tested) to get the shader compiler.
2. Run `glslc -fshader-stage=vertex shaders/vertex.glsl -o shaders/vertex.spv` to compile vertex shader.

// TODO: implement shader loading in assets.odin, asset hot reloading
