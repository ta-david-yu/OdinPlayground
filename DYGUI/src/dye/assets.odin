package dye

import "base:runtime"
import "core:hash"
import "core:os"
import "core:strings"
import "vendor:sdl3"
import "vendor:sdl3/ttf"

g_AssetDatabase: ^AssetDatabase = nil

AssetPathHash :: distinct u32

AssetDatabase :: struct {
	Allocator:         runtime.Allocator,
	Fonts:             map[AssetPathHash]FontAsset,
	GraphicsPipelines: map[AssetPathHash]GraphicsPipelineAsset,
}

AssetDescriptor :: struct {
	ID:    AssetPathHash,
	// A list of file paths that are associated with this asset.
	// Normally an asset will only have one associated path but some have more (e.g., graphics pipeline)
	Paths: [dynamic; 4]string,
}

FontAsset :: struct {
	using Descriptor: AssetDescriptor,
	Font:             ^ttf.Font,
	// The StreamIO to memory region that holds the font asset bytes.
	AssetIO:          ^sdl3.IOStream,
	// The font asset loaded into memory. We do this so ttf.OpenFont doesn't lock up the file, which prevent asset copying.
	AssetBytes:       []byte,
}

GraphicsPipelineAsset :: struct {
	using Descriptor: AssetDescriptor,
	Pipeline:         ^sdl3.GPUGraphicsPipeline,
}

Assets_GetGlobalAssetDatabase :: proc() -> ^AssetDatabase {
	return g_AssetDatabase
}

Assets_SetGlobalAssetDatabase :: proc(assetDatabase: ^AssetDatabase) {
	g_AssetDatabase = assetDatabase
}

Assets_CreateAssetDatabase :: proc(
	setAsGlobal: bool = true,
	allocator: runtime.Allocator = context.allocator,
) -> ^AssetDatabase {
	assetDatabase := new(AssetDatabase, allocator)

	assetDatabase.Allocator = allocator
	assetDatabase.Fonts = make(map[AssetPathHash]FontAsset, allocator)

	if (setAsGlobal) {
		Assets_SetGlobalAssetDatabase(assetDatabase)
	}

	return assetDatabase
}

Assets_ReleaseAssetDatabase :: proc(assetDatabase: ^AssetDatabase = nil) {
	assetDatabase := assetDatabase

	if (assetDatabase == nil) {
		assetDatabase = g_AssetDatabase
	}

	assert(assetDatabase != nil)

	allocator := assetDatabase.Allocator

	for key, value in assetDatabase.Fonts {
		Assets_UnloadFont(assetDatabase, value.ID)
	}
	delete(assetDatabase.Fonts)

	free(assetDatabase, allocator)
}

NoGlobalAssetDatabaseError :: struct {}

TTFNotInitError :: struct {}

TTFOpenFontError :: struct {
	ErrorMessage: cstring,
}

LoadAssetError :: union {
	NoGlobalAssetDatabaseError,
	TTFNotInitError,
	TTFOpenFontError,
	os.Error,
	runtime.Allocator_Error,
}

NotLoadedError :: struct {}

GetAssetError :: union {
	NoGlobalAssetDatabaseError,
	NotLoadedError,
}

Assets_GetOrLoadFont :: proc(
	path: string,
	defaultSize: f32 = 16,
) -> (
	fontAsset: FontAsset,
	err: LoadAssetError,
) {
	if (g_AssetDatabase == nil) {
		return fontAsset, NoGlobalAssetDatabaseError{}
	}

	if (ttf.WasInit() == 0) {
		return fontAsset, TTFNotInitError{}
	}

	hash := Assets_HashString(path)

	asset, isLoaded := g_AssetDatabase.Fonts[hash]
	if (isLoaded) {
		return asset, nil
	}

	// The asset hasn't been loaded yet.
	fontBytes := os.read_entire_file(path, g_AssetDatabase.Allocator) or_return
	fontIO := sdl3.IOFromConstMem(raw_data(fontBytes), uint(len(fontBytes)))
	if (fontIO == nil) {
		delete(fontBytes, g_AssetDatabase.Allocator)
		return fontAsset, TTFOpenFontError{ErrorMessage = sdl3.GetError()}
	}

	font := ttf.OpenFontIO(fontIO, false, defaultSize)
	if (font == nil) {
		sdl3.CloseIO(fontIO)
		delete(fontBytes, g_AssetDatabase.Allocator)
		return fontAsset, TTFOpenFontError{ErrorMessage = sdl3.GetError()}
	}

	fontAsset.ID = hash
	pathClone, pathCloneErr := strings.clone(path, g_AssetDatabase.Allocator) // Clone the string in case the user delete the path string.
	if (pathCloneErr != nil) {
		ttf.CloseFont(font)
		sdl3.CloseIO(fontIO)
		delete(fontBytes, g_AssetDatabase.Allocator)
		return fontAsset, pathCloneErr
	}
	append(&fontAsset.Paths, pathClone)
	fontAsset.Font = font
	fontAsset.AssetIO = fontIO
	fontAsset.AssetBytes = fontBytes
	g_AssetDatabase.Fonts[hash] = fontAsset
	return fontAsset, nil
}

Assets_GetFont :: proc(
	assetPathHash: AssetPathHash,
) -> (
	fontAsset: FontAsset,
	err: GetAssetError,
) {
	if (g_AssetDatabase == nil) {
		return fontAsset, NoGlobalAssetDatabaseError{}
	}

	asset, isLoaded := g_AssetDatabase.Fonts[assetPathHash]
	if (isLoaded) {
		return asset, nil
	}

	return fontAsset, NotLoadedError{}
}

Assets_UnloadFont :: proc {
	Assets_UnloadFontFromGlobalAssetDatabase,
	Assets_UnloadFontFromAssetDatabase,
}

Assets_UnloadFontFromGlobalAssetDatabase :: proc(assetPathHash: AssetPathHash) {
	if (g_AssetDatabase == nil) {
		return
	}

	Assets_UnloadFontFromAssetDatabase(g_AssetDatabase, assetPathHash)
}

Assets_UnloadFontFromAssetDatabase :: proc(
	assetDatabase: ^AssetDatabase,
	assetPathHash: AssetPathHash,
) {
	asset, isLoaded := g_AssetDatabase.Fonts[assetPathHash]
	if (!isLoaded) {
		return
	}

	for path in asset.Paths {
		delete(path, g_AssetDatabase.Allocator) // We cloned the path string when loading the asset, delete it here.
	}
	ttf.CloseFont(asset.Font)
	sdl3.CloseIO(asset.AssetIO)
	delete(asset.AssetBytes, g_AssetDatabase.Allocator)
}

Assets_GetOrLoadGraphicsPipeline :: proc(
	vertexPath: string,
	fragmentPath: string,
) -> (
	pipelineAsset: GraphicsPipelineAsset,
	err: LoadAssetError,
) {
	if (g_AssetDatabase == nil) {
		return pipelineAsset, NoGlobalAssetDatabaseError{}
	}

	concatedPathForHashing := strings.concatenate(
		{vertexPath, fragmentPath},
		context.temp_allocator,
	) or_return
	hash := Assets_HashString(concatedPathForHashing)

	asset, isLoaded := g_AssetDatabase.GraphicsPipelines[hash]
	if (isLoaded) {
		return asset, nil
	}

	// The asset hasn't been loaded yet.

	// Load vertex shader
	vertexCode := os.read_entire_file(vertexPath, context.temp_allocator) or_return

	vertexInfo: sdl3.GPUShaderCreateInfo = {
		code = nil,
	}

	// TODO
	return asset, nil
}

Assets_HashString :: proc(path: string) -> AssetPathHash {
	return cast(AssetPathHash)hash.murmur32(transmute([]byte)path)
}
