package dye

import "base:runtime"
import hm "core:container/handle_map"
import "core:encoding/json"
import "core:fmt"
import "core:hash"
import "core:os"
import "core:slice"
import "core:strings"
import "vendor:sdl3"
import "vendor:sdl3/ttf"

g_AssetDatabase: ^AssetDatabase = nil

AssetHash :: distinct u32

AssetType :: enum {
	Font,
	GraphicsPipeline,
}

AssetHandle :: struct {
	using _:  hm.Handle64,
	Type:     AssetType,
	PathHash: AssetHash,
}

AssetDatabase :: struct {
	GPUDevice:                        ^sdl3.GPUDevice,
	MainWindowSwapchainTextureFormat: sdl3.GPUTextureFormat,
	Allocator:                        runtime.Allocator,
	AssetMap:                         map[AssetHash]AssetHandle,
	Fonts:                            hm.Dynamic_Handle_Map(FontAsset, AssetHandle),
	GraphicsPipelines:                hm.Dynamic_Handle_Map(GraphicsPipelineAsset, AssetHandle),
}

FontAsset :: struct {
	using handle: AssetHandle,
	// A list of file paths that are associated with this asset.
	// Normally an asset will only have one associated path but some have more (e.g., graphics pipeline)
	Paths:        [dynamic; 4]string,
	Font:         ^ttf.Font,
	// The StreamIO to memory region that holds the font asset bytes.
	AssetIO:      ^sdl3.IOStream,
	// The font asset loaded into memory. We do this so ttf.OpenFont doesn't lock up the file, which prevent asset copying.
	AssetBytes:   []byte,
}

GraphicsPipelineAsset :: struct {
	using handle: AssetHandle,
	// A list of file paths that are associated with this asset.
	// Normally an asset will only have one associated path but some have more (e.g., graphics pipeline)
	Paths:        [dynamic; 4]string,
	Pipeline:     ^sdl3.GPUGraphicsPipeline,
}

ShaderIOInfo :: struct {
	name:     string,
	type:     string,
	location: u32,
}

ShaderInfo :: struct {
	samplers:         u32,
	storage_textures: u32,
	storage_buffers:  u32,
	uniform_buffers:  u32,
	inputs:           []ShaderIOInfo,
	outputs:          []ShaderIOInfo,
}

Assets_GetGlobalAssetDatabase :: proc() -> ^AssetDatabase {
	return g_AssetDatabase
}

Assets_SetGlobalAssetDatabase :: proc(assetDatabase: ^AssetDatabase) {
	g_AssetDatabase = assetDatabase
}

Assets_CreateAssetDatabase :: proc(
	gpuDevice: ^sdl3.GPUDevice,
	windowSwapchainTextureFormat: sdl3.GPUTextureFormat,
	setAsGlobal: bool = true,
	allocator: runtime.Allocator = context.allocator,
) -> ^AssetDatabase {
	assetDatabase := new(AssetDatabase, allocator)

	assetDatabase.GPUDevice = gpuDevice
	assetDatabase.MainWindowSwapchainTextureFormat = windowSwapchainTextureFormat
	assetDatabase.Allocator = allocator

	assetDatabase.AssetMap = make(map[AssetHash]AssetHandle, allocator)
	hm.dynamic_init(&assetDatabase.Fonts, allocator)
	hm.dynamic_init(&assetDatabase.GraphicsPipelines, allocator)

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

	fontItr := hm.iterator_make(&assetDatabase.Fonts)
	for asset, handle in hm.iterate(&fontItr) {
		Assets_UnloadFont(assetDatabase, handle)
	}
	hm.dynamic_destroy(&assetDatabase.Fonts)

	pipelineItr := hm.iterator_make(&assetDatabase.GraphicsPipelines)
	for asset, handle in hm.iterate(&pipelineItr) {
		Assets_UnloadGraphicsPipeline(assetDatabase, handle)
	}
	hm.dynamic_destroy(&assetDatabase.GraphicsPipelines)

	delete(assetDatabase.AssetMap)

	free(assetDatabase, allocator)
}

NoGlobalAssetDatabaseError :: struct {}

AssetTypeMismatchError :: struct {}

AssetExpiredError :: struct {}

TTFNotInitError :: struct {}

TTFOpenFontError :: struct {
	ErrorMessage: cstring,
}

CreateShaderError :: struct {
	ErrorMessage: cstring,
}

LoadAssetError :: union {
	NoGlobalAssetDatabaseError,
	AssetTypeMismatchError,
	AssetExpiredError,
	TTFNotInitError,
	TTFOpenFontError,
	os.Error,
	runtime.Allocator_Error,
	json.Unmarshal_Error,
	CreateShaderError,
}

NotLoadedError :: struct {}

GetAssetError :: union {
	NoGlobalAssetDatabaseError,
	NotLoadedError,
	AssetTypeMismatchError,
}

Assets_GetAssetHandleFromHash :: proc(assetHash: AssetHash) -> AssetHandle {
	if (g_AssetDatabase == nil) {
		return AssetHandle{}
	}

	handle, exist := g_AssetDatabase.AssetMap[assetHash]
	if (!exist) {
		return AssetHandle{}
	}

	return handle
}

Assets_GetOrLoadFont :: proc(
	path: string,
	defaultSize: f32 = 16,
) -> (
	fontAsset: FontAsset,
	err: LoadAssetError,
) {
	fontAsset.handle.Type = .Font

	if (g_AssetDatabase == nil) {
		return fontAsset, NoGlobalAssetDatabaseError{}
	}

	if (ttf.WasInit() == 0) {
		return fontAsset, TTFNotInitError{}
	}

	hash := Assets_HashString(path)

	assetHandle, isLoaded := g_AssetDatabase.AssetMap[hash]
	if (isLoaded) {
		if (assetHandle.Type != .Font) {
			return fontAsset, AssetTypeMismatchError{}
		}

		asset, result := hm.get(&g_AssetDatabase.Fonts, assetHandle)
		if (!result) {
			return fontAsset, AssetExpiredError{}
		} else {
			return asset^, nil
		}
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

	fontAsset.handle.PathHash = hash
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

	handle := hm.add(&g_AssetDatabase.Fonts, fontAsset)
	g_AssetDatabase.AssetMap[hash] = handle

	return fontAsset, nil
}

Assets_GetFont :: proc(handle: AssetHandle) -> (fontAsset: FontAsset, err: GetAssetError) {
	if (g_AssetDatabase == nil) {
		return fontAsset, NoGlobalAssetDatabaseError{}
	}

	if (handle.Type != .Font) {
		return fontAsset, AssetTypeMismatchError{}
	}

	asset, result := hm.get(&g_AssetDatabase.Fonts, handle)
	if (result) {
		return asset^, nil
	}

	return fontAsset, NotLoadedError{}
}

Assets_UnloadFont :: proc {
	Assets_UnloadFontFromGlobalAssetDatabase,
	Assets_UnloadFontFromAssetDatabase,
}

Assets_UnloadFontFromGlobalAssetDatabase :: proc(handle: AssetHandle) {
	if (g_AssetDatabase == nil) {
		return
	}

	Assets_UnloadFontFromAssetDatabase(g_AssetDatabase, handle)
}

Assets_UnloadFontFromAssetDatabase :: proc(assetDatabase: ^AssetDatabase, handle: AssetHandle) {
	if (handle.Type != .Font) {
		return
	}

	asset, result := hm.get(&g_AssetDatabase.Fonts, handle)
	if (!result) {
		return
	}

	for path in asset.Paths {
		delete(path, g_AssetDatabase.Allocator) // We cloned the path string when loading the asset, delete it here.
	}
	ttf.CloseFont(asset.Font)
	sdl3.CloseIO(asset.AssetIO)
	delete(asset.AssetBytes, g_AssetDatabase.Allocator)

	hm.remove(&g_AssetDatabase.Fonts, handle)
	delete_key(&assetDatabase.AssetMap, handle.PathHash)
}

Assets_GetOrLoadGraphicsPipeline :: proc(
	vertexPath: string,
	fragmentPath: string,
) -> (
	pipelineAsset: GraphicsPipelineAsset,
	err: LoadAssetError,
) {
	// TODO: add more parameters? or provide custom shader syntax to specify blend state, depth/stencil flags, target texture format etc
	pipelineAsset.handle.Type = .GraphicsPipeline

	if (g_AssetDatabase == nil) {
		return pipelineAsset, NoGlobalAssetDatabaseError{}
	}

	concatedPathForHashing := strings.concatenate(
		{vertexPath, fragmentPath},
		context.temp_allocator,
	) or_return
	hash := Assets_HashString(concatedPathForHashing)

	assetHandle, isLoaded := g_AssetDatabase.AssetMap[hash]
	if (isLoaded) {
		if (assetHandle.Type != .GraphicsPipeline) {
			return pipelineAsset, AssetTypeMismatchError{}
		}

		asset, result := hm.get(&g_AssetDatabase.GraphicsPipelines, assetHandle)
		if (!result) {
			return pipelineAsset, AssetExpiredError{}
		} else {
			return asset^, nil
		}
	}

	// The asset hasn't been loaded yet.

	// Load vertex shader.
	// See https://wiki.libsdl.org/SDL3/SDL_CreateGPUShader for more details on resource sets.
	vertexShader: ^sdl3.GPUShader
	vertexElementSize: u32 = 0
	vertexAttributes: [dynamic]sdl3.GPUVertexAttribute = make(
		[dynamic]sdl3.GPUVertexAttribute,
		context.temp_allocator,
	)
	{
		vertexCode := os.read_entire_file(vertexPath, context.temp_allocator) or_return

		// Load vertex shader info
		vertexInfoPath := os.join_filename(vertexPath, "json", context.temp_allocator) or_return
		vertexInfoJson := os.read_entire_file(vertexInfoPath, context.temp_allocator) or_return

		vertexInfo: ShaderInfo
		vertexInfoParseErr := json.unmarshal(
			vertexInfoJson,
			&vertexInfo,
			allocator = context.temp_allocator,
		)
		if (vertexInfoParseErr != nil) {
			return pipelineAsset, vertexInfoParseErr
		}

		slice.sort_by(vertexInfo.inputs, proc(a, b: ShaderIOInfo) -> bool {
			return a.location < b.location
		})

		inputOffset: u32
		for input in vertexInfo.inputs {
			format := Assets_ParseShaderVertexElementFormatFromString(input.type)
			append(
				&vertexAttributes,
				sdl3.GPUVertexAttribute {
					buffer_slot = 0, // For now, we always only use one vertex buffer
					location    = input.location,
					format      = format,
					offset      = inputOffset,
				},
			)

			attributeSize := Assets_ShaderVertexElementByteSize(format)
			inputOffset += attributeSize
			vertexElementSize += attributeSize
		}

		vertexCreateInfo: sdl3.GPUShaderCreateInfo = {
			code                 = raw_data(vertexCode),
			code_size            = len(vertexCode),
			entrypoint           = "main",
			format               = {.SPIRV},
			stage                = .VERTEX,
			num_samplers         = vertexInfo.samplers,
			num_storage_textures = vertexInfo.storage_textures,
			num_storage_buffers  = vertexInfo.storage_buffers,
			num_uniform_buffers  = vertexInfo.uniform_buffers,
		}

		vertexShader = sdl3.CreateGPUShader(g_AssetDatabase.GPUDevice, vertexCreateInfo)
		if (vertexShader == nil) {
			return pipelineAsset, CreateShaderError{ErrorMessage = sdl3.GetError()}
		}
	}
	defer sdl3.ReleaseGPUShader(g_AssetDatabase.GPUDevice, vertexShader)

	// Load fragment shader
	fragmentShader: ^sdl3.GPUShader
	{
		fragmentCode := os.read_entire_file(fragmentPath, context.temp_allocator) or_return

		// Load vertex shader info
		fragmentInfoPath := os.join_filename(
			fragmentPath,
			"json",
			context.temp_allocator,
		) or_return
		fragmentInfoJson := os.read_entire_file(fragmentInfoPath, context.temp_allocator) or_return

		fragmentInfo: ShaderInfo
		fragmentInfoParseErr := json.unmarshal(
			fragmentInfoJson,
			&fragmentInfo,
			allocator = context.temp_allocator,
		)
		if (fragmentInfoParseErr != nil) {
			return pipelineAsset, fragmentInfoParseErr
		}

		fragmentCreateInfo: sdl3.GPUShaderCreateInfo = {
			code                 = raw_data(fragmentCode),
			code_size            = len(fragmentCode),
			entrypoint           = "main",
			format               = {.SPIRV},
			stage                = .FRAGMENT,
			num_samplers         = fragmentInfo.samplers,
			num_storage_textures = fragmentInfo.storage_textures,
			num_storage_buffers  = fragmentInfo.storage_buffers,
			num_uniform_buffers  = fragmentInfo.uniform_buffers,
		}

		fragmentShader = sdl3.CreateGPUShader(g_AssetDatabase.GPUDevice, fragmentCreateInfo)
		if (fragmentShader == nil) {
			return pipelineAsset, CreateShaderError{ErrorMessage = sdl3.GetError()}
		}
	}
	defer sdl3.ReleaseGPUShader(g_AssetDatabase.GPUDevice, fragmentShader)

	vertexBufferDescriptions: [1]sdl3.GPUVertexBufferDescription = {
		sdl3.GPUVertexBufferDescription {
			slot = 0,
			input_rate = sdl3.GPUVertexInputRate.VERTEX,
			instance_step_rate = 0,
			pitch = vertexElementSize,
		},
	}

	colorTargetDescriptions: [1]sdl3.GPUColorTargetDescription = {
		sdl3.GPUColorTargetDescription{format = g_AssetDatabase.MainWindowSwapchainTextureFormat},
	}

	pipelineCreateInfo: sdl3.GPUGraphicsPipelineCreateInfo = {
		vertex_shader = vertexShader,
		fragment_shader = fragmentShader,
		primitive_type = sdl3.GPUPrimitiveType.TRIANGLELIST,
		vertex_input_state = {
			num_vertex_buffers = 1,
			vertex_buffer_descriptions = raw_data(vertexBufferDescriptions[:]),
			num_vertex_attributes = cast(u32)len(vertexAttributes),
			vertex_attributes = raw_data(vertexAttributes),
		},
		depth_stencil_state = {
			enable_depth_test = true,
			enable_depth_write = true,
			compare_op = .LESS,
		},
		rasterizer_state = {cull_mode = .BACK},
		target_info = {
			num_color_targets = 1,
			color_target_descriptions = raw_data(colorTargetDescriptions[:]),
		},
	}

	pipeline := sdl3.CreateGPUGraphicsPipeline(g_AssetDatabase.GPUDevice, pipelineCreateInfo)
	if (pipeline == nil) {
		return pipelineAsset, CreateShaderError{ErrorMessage = sdl3.GetError()}
	}

	pipelineAsset.handle.PathHash = hash

	append(
		&pipelineAsset.Paths,
		strings.clone(vertexPath, g_AssetDatabase.Allocator),
		strings.clone(fragmentPath, g_AssetDatabase.Allocator),
	)
	pipelineAsset.Pipeline = pipeline

	handle := hm.add(&g_AssetDatabase.GraphicsPipelines, pipelineAsset)
	g_AssetDatabase.AssetMap[hash] = handle

	return pipelineAsset, nil
}

Assets_GetGraphicsPipeline :: proc(
	handle: AssetHandle,
) -> (
	pipelineAsset: GraphicsPipelineAsset,
	err: GetAssetError,
) {
	if (g_AssetDatabase == nil) {
		return pipelineAsset, NoGlobalAssetDatabaseError{}
	}

	if (handle.Type != .GraphicsPipeline) {
		return pipelineAsset, AssetTypeMismatchError{}
	}

	asset, result := hm.get(&g_AssetDatabase.GraphicsPipelines, handle)
	if (result) {
		return asset^, nil
	}

	return pipelineAsset, NotLoadedError{}
}

Assets_UnloadGraphicsPipeline :: proc {
	Assets_UnloadGraphicsPipelineFromGlobalAssetDatabase,
	Assets_UnloadGraphicsPipelineFromAssetDatabase,
}

Assets_UnloadGraphicsPipelineFromGlobalAssetDatabase :: proc(handle: AssetHandle) {
	if (g_AssetDatabase == nil) {
		return
	}

	Assets_UnloadGraphicsPipelineFromAssetDatabase(g_AssetDatabase, handle)
}

Assets_UnloadGraphicsPipelineFromAssetDatabase :: proc(
	assetDatabase: ^AssetDatabase,
	handle: AssetHandle,
) {
	if (handle.Type != .GraphicsPipeline) {
		return
	}

	asset, result := hm.get(&g_AssetDatabase.GraphicsPipelines, handle)
	if (!result) {
		return
	}

	for path in asset.Paths {
		delete(path, g_AssetDatabase.Allocator) // We cloned the path string when loading the asset, delete it here.
	}
	sdl3.ReleaseGPUGraphicsPipeline(g_AssetDatabase.GPUDevice, asset.Pipeline)

	hm.remove(&g_AssetDatabase.GraphicsPipelines, handle)
	delete_key(&assetDatabase.AssetMap, handle.PathHash)
}

Assets_HashString :: proc(path: string) -> AssetHash {
	return cast(AssetHash)hash.murmur32(transmute([]byte)path)
}

Assets_ParseShaderVertexElementFormatFromString :: proc(
	type: string,
) -> sdl3.GPUVertexElementFormat {
	switch type {
	case "int":
		return sdl3.GPUVertexElementFormat.INT
	case "int2":
		return sdl3.GPUVertexElementFormat.INT2
	case "int3":
		return sdl3.GPUVertexElementFormat.INT3
	case "int4":
		return sdl3.GPUVertexElementFormat.INT4
	case "float":
		return sdl3.GPUVertexElementFormat.FLOAT
	case "float2":
		return sdl3.GPUVertexElementFormat.FLOAT2
	case "float3":
		return sdl3.GPUVertexElementFormat.FLOAT3
	case "float4":
		return sdl3.GPUVertexElementFormat.FLOAT4
	// TODO: more types in the future, for now only for testing
	}


	return sdl3.GPUVertexElementFormat.INVALID
}

Assets_ShaderVertexElementByteSize :: proc(format: sdl3.GPUVertexElementFormat) -> u32 {
	#partial switch format {
	case .INT, .FLOAT:
		return 4
	case .INT2, .FLOAT2:
		return 8
	case .INT3, .FLOAT3:
		return 12
	case .INT4, .FLOAT4:
		return 16
	// TODO: more types in the future, for now only for testing
	}

	return 0
}
