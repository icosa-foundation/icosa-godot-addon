@tool
class_name IcosaGLTF
extends GLTFDocumentExtension

## Generic GLTF fixes for Icosa assets (byteStride, Blocks single-root).
## Registered in plugin.gd alongside IcosaTiltGLTF.


func _import_preflight(gltf_state: GLTFState, extensions: PackedStringArray) -> Error:
	var gltf_json_variant := gltf_state.json
	if not (gltf_json_variant is Dictionary):
		return OK
	var gltf_json: Dictionary = gltf_json_variant

	# Fix invalid byteStride values
	if gltf_json.has("bufferViews"):
		var buffer_views = gltf_json["bufferViews"]
		if buffer_views is Array:
			for i in range(buffer_views.size()):
				var bv: Dictionary = buffer_views[i]
				if not bv.has("byteStride"):
					continue
				var stride: int = bv["byteStride"]
				if stride < 4 or stride > 252 or stride % 4 != 0:
					bv.erase("byteStride")

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

	return OK
