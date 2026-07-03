package asset_copy

import "base:runtime"
import "core:c/libc"
import "core:fmt"
import "core:hash"
import "core:os"
import "core:strings"
import "core:sys/windows"
import "core:thread"
import "core:time"

AssetInfo :: struct {
	Timestamp: time.Time,
}

main :: proc() {
	if (len(os.args) <= 2) {
		fmt.printf(
			"[asset-copy] Missing arguments, 2 required: asset_copy.exe [source-asset-folder-path] [destination-asset-folder-path]",
		)
		return
	}

	srcFolder := os.args[1]
	dstFolder := os.args[2]

	fmt.printfln("src: {0}", srcFolder)
	fmt.printfln("dst: {0}", dstFolder)

	assetInfos: map[u32]AssetInfo = make(map[u32]AssetInfo)

	watchFileThreshold := 300 * time.Millisecond
	watchFileTimer: time.Duration = watchFileThreshold
	lastLoopTick := time.tick_now()

	animationFrames := []string{"Idle", "Idle.", "Idle..", "Idle..."}
	animationFrameCounter := 0
	for {
		loopTick := time.tick_now()
		watchFileTimer += time.tick_diff(lastLoopTick, loopTick)
		lastLoopTick = loopTick

		if (windows.GetAsyncKeyState(windows.VK_F5) & 1) != 0 {
			fmt.println("[asset-copy] Force refresh and copy all assets")
			clear(&assetInfos)
			watchFileTimer = watchFileThreshold
		}

		if watchFileTimer < watchFileThreshold {
			thread.yield()
			continue
		}
		watchFileTimer = 0

		fileWalker := os.walker_create(srcFolder)
		defer os.walker_destroy(&fileWalker)

		isAnyAssetUpdateThisLoop := false
		for info in os.walker_walk(&fileWalker) {
			if (info.type != .Regular) {
				continue
			}

			hash := HashString(info.fullpath)
			timestamp := os.last_write_time_by_name(info.fullpath) or_continue

			assetInfo, wasTracked := &assetInfos[hash]
			if (!wasTracked) {
				// This is a new asset that hasn't been tracked yet.
				// Copy the asset and then push it into the map.
				dstAssetPath := CopyAssetFromSrcToDst(
					srcFolder,
					dstFolder,
					info.fullpath,
				) or_continue

				fmt.eprintfln("[asset-copy] Copied new file: %s", info.fullpath)
				CheckIfAssetPathIsShaderAndCompile(dstAssetPath)

				assetInfos[hash] = AssetInfo {
					Timestamp = timestamp,
				}
				continue
			}

			isAssetDirty := assetInfo.Timestamp != timestamp
			if (isAssetDirty) {
				dstAssetPath := CopyAssetFromSrcToDst(
					srcFolder,
					dstFolder,
					info.fullpath,
				) or_continue

				fmt.eprintfln("\n[asset-copy] Updated file: %s", info.fullpath)
				CheckIfAssetPathIsShaderAndCompile(dstAssetPath)

				assetInfo^ = {
					Timestamp = timestamp,
				}
				isAnyAssetUpdateThisLoop = true
			}
		}

		if (!isAnyAssetUpdateThisLoop) {
			fmt.printf("\x1b[2K\r{0}", animationFrames[animationFrameCounter])
			animationFrameCounter += 1
			if animationFrameCounter >= len(animationFrames) {
				animationFrameCounter = 0
			}
		}

		free_all(context.temp_allocator)
	}

	delete(assetInfos)
}

HashString :: proc(path: string) -> u32 {
	return hash.murmur32(transmute([]byte)path)
}


CopyAssetFromSrcToDst :: proc(
	srcFolder: string,
	dstFolder: string,
	srcAssetPath: string,
) -> (
	dstAssetPath: string,
	result: bool,
) {
	assetRelativeFile := strings.trim_prefix(srcAssetPath, srcFolder)
	assetRelativeFile = strings.trim_left(assetRelativeFile, os.Path_Separator_Chars)

	dst, joinPathErr := os.join_path({dstFolder, assetRelativeFile}, context.temp_allocator)
	if (joinPathErr != .None) {
		return dstAssetPath, false
	}

	dstAssetPath = dst
	assetDstDir := os.dir(dstAssetPath)
	err := os.make_directory_all(assetDstDir)
	if (err != nil && err != .Exist) {
		fmt.eprintfln("[asset-copy] Failed creating dir %s: %v", assetDstDir, err)
		return dstAssetPath, false
	}

	err = os.copy_file(dstAssetPath, srcAssetPath)
	if err != nil {
		fmt.eprintfln("[asset-copy] Failed copying %s -> %s: %v", srcAssetPath, dstAssetPath, err)
		return dstAssetPath, false
	}

	return dstAssetPath, true
}

CheckIfAssetPathIsShaderAndCompile :: proc(dstAssetPath: string) {
	isShader :=
		strings.has_suffix(dstAssetPath, ".vert") || strings.has_suffix(dstAssetPath, ".frag")
	if (isShader) {
		// Also compile shader files if possible.
		extension := os.ext(dstAssetPath)
		dstAssetPathWithoutExt := dstAssetPath[:len(dstAssetPath) - len(extension)]

		outputPath, err := os.join_filename(dstAssetPathWithoutExt, "spv", context.temp_allocator)
		if (err != nil) {
			return
		}

		compileCmd := fmt.ctprintf("glslc %s -o %s", dstAssetPath, outputPath)
		if libc.system(compileCmd) != 0 {
			fmt.println("[asset-copy] Failed to compile shader: ", dstAssetPath, " > ", outputPath)
		} else {
			fmt.println("[asset-copy] Compiled shader: ", dstAssetPath, " > ", outputPath)
		}
	}
}
