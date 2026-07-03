package asset_copy

import "base:runtime"
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
			fmt.println("Force refresh and copy all assets")
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
				if (!CopyAssetFromSrcToDst(srcFolder, dstFolder, info.fullpath)) {
					continue
				}

				fmt.eprintfln("[asset-copy] Copy new file: %s", info.fullpath)

				assetInfos[hash] = AssetInfo {
					Timestamp = timestamp,
				}
				continue
			}

			isAssetDirty := assetInfo.Timestamp != timestamp
			if (isAssetDirty) {
				if (!CopyAssetFromSrcToDst(srcFolder, dstFolder, info.fullpath)) {
					continue
				}

				fmt.eprintfln("\n[asset-copy] Update and copy file: %s", info.fullpath)
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


CopyAssetFromSrcToDst :: proc(srcFolder: string, dstFolder: string, srcAssetPath: string) -> bool {
	assetRelativeFile := strings.trim_prefix(srcAssetPath, srcFolder)
	assetRelativeFile = strings.trim_left(assetRelativeFile, os.Path_Separator_Chars)

	assetDst, joinPathErr := os.join_path({dstFolder, assetRelativeFile}, context.temp_allocator)
	if (joinPathErr != .None) {
		return false
	}

	assetDstDir := os.dir(assetDst)
	err := os.make_directory_all(assetDstDir)
	if (err != nil && err != .Exist) {
		fmt.eprintfln("[asset-copy] failed creating dir %s: %v", assetDstDir, err)
		return false
	}

	err = os.copy_file(assetDst, srcAssetPath)
	if err != nil {
		fmt.eprintfln("[asset-copy] failed copying %s -> %s: %v", srcAssetPath, assetDst, err)
		return false
	}

	return true
}
