# Getting Started

The project has hot-reloading support. The actual game/app logic is built as dll and the main.exe loads the dll dynamically.

To simply build and run the project, do the following in the command line:

1. Run `./scripts/app-dll-build.bat` to build the `app.dll`.
2. Run `./scripts/main-exe-build-and-run.bat` to build the executable and run it. Note that this script also copies the necessary extern dlls and assets into the output folder.
3. When the `main.exe` is running, you can trigger the first step as many time as you wanted to hot-reload your app logic.

To automatically watch any changes on the files that contributes to `app.dll` and rebuild it:

1. Run `./scripts/builder-exe-build-and-run.bat` to build the `builder.exe` and run it. `builder.exe` watches any changes on the relevant files and build new `app.dll` when needed.
2. Run `./scripts/main-exe-build-and-run.bat` to build the executable and run it. Note that this script also copies the necessary extern dlls and assets into the output folder.
