package builder

import "base:runtime"
import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:time"

main :: proc() {
	filesToWatch: []runtime.Load_Directory_File = #load_directory("../src/app")
	fileTimestamps: []os.File_Time = make([]os.File_Time, len(filesToWatch))
	defer delete(fileTimestamps)

	// Init timestamps
	for i := 0; i < len(filesToWatch); i += 1 {
		file := filesToWatch[i]
		fileName := file.name
		filePath := fmt.tprintf("{0}/{1}", "./src/app", fileName)
		timestamp, error := os.last_write_time_by_name(filePath)
		if error != nil {
			fmt.printfln("Error reading {0}: {1}", filePath, error)
		}
		fileTimestamps[i] = timestamp
		fmt.printfln("Watching file: {0}, time: {1}", fileName, timestamp)
	}

	// Inifinte loop to check if dll needs to be rebuilt
	animationFrames := []string{"Idle", "Idle.", "Idle..", "Idle..."}
	animationFrameCounter := 0
	for {
		time.sleep(300 * time.Millisecond)

		shouldRebuildDLL := false
		for i := 0; i < len(filesToWatch); i += 1 {
			file := filesToWatch[i]
			fileName := file.name
			filePath := fmt.tprintf("{0}/{1}", "./src/app", fileName)
			timestamp, error := os.last_write_time_by_name(filePath)
			if error != nil {
				fmt.printf("\nError reading {0}: {1}", filePath, error)
			} else {
				if fileTimestamps[i] != timestamp {
					fmt.printf("\n{0} is dirty ({1})", fileName, timestamp)
					shouldRebuildDLL = true
				}
			}
			fileTimestamps[i] = timestamp
		}

		if shouldRebuildDLL {
			buildCmd := fmt.ctprintf(
				"odin build src\\app -debug -build-mode:dll -out:\"build\\debug\\app.dll\"",
			)
			if libc.system(buildCmd) != 0 {
				fmt.println("Failed to build dll")
			} else {
				fmt.println("DLL built!")
			}
		} else {
			fmt.printf("\x1b[2K\r{0}", animationFrames[animationFrameCounter])
			animationFrameCounter += 1
			if animationFrameCounter >= len(animationFrames) {
				animationFrameCounter = 0
			}
		}
	}

	return
}
