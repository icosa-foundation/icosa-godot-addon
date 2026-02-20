@tool
class_name IcosaGLTF
extends GLTFDocumentExtension

enum AssetType {GLTF1, GLTF2, TILT, BLOCKS}

## GLTF2 is the expected result of ALL imported gltf assets
var asset_type: AssetType = AssetType.GLTF2

var _tilt = null
var _gltf_json_cache: Dictionary = {}


func _import_preflight(gltf_state: GLTFState, extensions: PackedStringArray) -> Error:
	var gltf_json_variant := gltf_state.json
	if not (gltf_json_variant is Dictionary):
		return OK
	var gltf_json: Dictionary = gltf_json_variant

	# Detect asset type
	if gltf_json["asset"]["version"] == "1.0":
		asset_type = AssetType.GLTF1

	if gltf_json["asset"].has("generator"):
		var generator: String = gltf_json["asset"]["generator"]
		if generator.begins_with("Obj2GltfConverter"):
			asset_type = AssetType.GLTF2
		if generator.ends_with("glTF 1-to-2 Upgrader for Google Blocks"):
			asset_type = AssetType.BLOCKS
		if generator.begins_with("Tilt Brush") or generator.begins_with("Open Brush"):
			asset_type = AssetType.TILT

	# Fix invalid byteStride values (generic — applies to all asset types)
	if gltf_json.has("bufferViews"):
		var buffer_views = gltf_json["bufferViews"]
		if buffer_views is Array:
			for i in range(buffer_views.size()):
				var buffer_view_dict: Dictionary = buffer_views[i]
				if not buffer_view_dict.has("byteStride"):
					continue
				var stride: int = buffer_view_dict["byteStride"]
				if stride < 4 or stride > 252 or stride % 4 != 0:
					buffer_view_dict.erase("byteStride")

	# Obj2Gltf / Blocks: add GODOT_single_root extension hint
	var asset = gltf_json.get("asset")
	if asset is Dictionary and (
			asset.get("generator") == "Obj2GltfConverter" or
			asset.get("generator") == "glTF 1-to-2 Upgrader for Google Blocks"):
		var meshes = gltf_json.get("meshes")
		if meshes is Array and meshes.size() == 1:
			if extensions.has("GOOGLE_backgrounds") and extensions.has("GOOGLE_camera_settings"):
				var ext_used: Array = gltf_json["extensionsUsed"]
				ext_used.append("GODOT_single_root")

	# TILT-specific preflight
	if asset_type == AssetType.TILT:
		_ensure_tilt()
		_gltf_json_cache = gltf_json
		_tilt.preflight(gltf_json)

	return OK


func _import_post_parse(gltf_state: GLTFState) -> Error:
	if asset_type == AssetType.TILT:
		_ensure_tilt()
		_tilt.post_parse(gltf_state)
	return OK


func _import_post(gltf_state: GLTFState, root: Node) -> Error:
	if asset_type == AssetType.TILT:
		_ensure_tilt()
		_tilt.apply_lights(root, _gltf_json_cache)
	return OK


func _ensure_tilt() -> void:
	if _tilt == null:
		_tilt = IcosaTiltImport.new()
		_tilt.setup()
