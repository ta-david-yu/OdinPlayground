package builder

import "base:runtime"
import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:time"

DirectoryFileInfo :: struct {
	Directory: string,
	File:      runtime.Load_Directory_File,
}

main :: proc() {
	isDebug := false

	if len(os.args) > 1 {
		isDebug = os.args[1] == "debug"

		if isDebug {
			fmt.println("Building dll with debug flag")
		}
	}

	// Build once at the startup
	executeProcToBuildDLL(isDebug)

	filesToWatch: [dynamic]DirectoryFileInfo

	for file in #load_directory("../src/app") {
		append(&filesToWatch, DirectoryFileInfo{File = file, Directory = "./src/app"})
	}
	for file in #load_directory("../src/dye") {
		append(&filesToWatch, DirectoryFileInfo{File = file, Directory = "./src/dye"})
	}
	for file in #load_directory("../src/dye/gui") {
		append(&filesToWatch, DirectoryFileInfo{File = file, Directory = "./src/dye/gui"})
	}
	for file in #load_directory("../src/dye/prof") {
		append(&filesToWatch, DirectoryFileInfo{File = file, Directory = "./src/dye/prof"})
	}

	fileTimestamps: []time.Time = make([]time.Time, len(filesToWatch))
	defer delete(fileTimestamps)

	// Init timestamps
	for i := 0; i < len(filesToWatch); i += 1 {
		file := filesToWatch[i]
		fileName := file.File.name
		filePath := fmt.tprintf("{0}/{1}", file.Directory, fileName)
		timestamp, error := os.last_write_time_by_name(filePath)
		if error != nil {
			fmt.printfln("Error reading {0}: {1}", filePath, error)
		}
		fileTimestamps[i] = timestamp
		fmt.printfln("Watching file: {0}, time: {1}:", fileName, timestamp)
	}

	// Inifinte loop to check if dll needs to be rebuilt
	animationFrames := []string{"Idle", "Idle.", "Idle..", "Idle..."}
	animationFrameCounter := 0
	for {
		time.sleep(300 * time.Millisecond)

		shouldRebuildDLL := false
		for i := 0; i < len(filesToWatch); i += 1 {
			file := filesToWatch[i]
			fileName := file.File.name
			filePath := fmt.tprintf("{0}/{1}", file.Directory, fileName)
			timestamp, error := os.last_write_time_by_name(filePath)
			if error != nil {
				fmt.printf("\nError reading {0}: {1}", filePath, error)
			} else {
				if fileTimestamps[i] != timestamp {
					fmt.printfln("\n{0} is dirty ({1})", fileName, timestamp)
					shouldRebuildDLL = true
				}
			}
			fileTimestamps[i] = timestamp
		}

		if shouldRebuildDLL {
			executeProcToBuildDLL(isDebug)
		} else {
			fmt.printf("\x1b[2K\r{0}", animationFrames[animationFrameCounter])
			animationFrameCounter += 1
			if animationFrameCounter >= len(animationFrames) {
				animationFrameCounter = 0
			}
		}

		// Release memory in the temp allocator at the end of the frame
		free_all(context.temp_allocator)
	}

	return
}

executeProcToBuildDLL :: proc(isDebug: bool) {
	if (isDebug) {
		os.make_directory_all("build/debug")
	} else {
		os.make_directory_all("build/release")
	}

	buildCmd :=
		!isDebug ? fmt.ctprintf("odin build src\\app -build-mode:dll -out:\"build\\release\\app.dll\"") : fmt.ctprintf("odin build src\\app -debug -build-mode:dll -out:\"build\\debug\\app.dll\"")
	if libc.system(buildCmd) != 0 {
		fmt.println("Failed to build dll")
	} else {
		fmt.println("DLL built!")
	}
}
