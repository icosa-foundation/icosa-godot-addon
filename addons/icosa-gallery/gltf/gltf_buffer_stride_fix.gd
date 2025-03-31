@tool
class_name IcosaGLTFDocumentExtension
extends GLTFDocumentExtension

var has_google_extensions = false

## written by aaronfranke. thank you!
func _import_preflight(gltf_state: GLTFState, extensions: PackedStringArray) -> Error:
	# HACK: This is workaround for an issue fixed in Godot 4.5.
	var gltf_json: Dictionary = gltf_state.json
	if not gltf_json.has("bufferViews"):
		return OK
	var buffer_views: Array = gltf_json["bufferViews"]
	for i in range(buffer_views.size()):
		var buffer_view_dict: Dictionary = buffer_views[i]
		if not buffer_view_dict.has("byteStride"):
			continue
		var stride: int = buffer_view_dict["byteStride"]
		if stride < 4 or stride > 252 or stride % 4 != 0:
			printerr("glTF import: Invalid byte stride " + str(stride) + " for buffer view at index " + str(i) + " while importing file '" + gltf_state.filename + "'. If defined, byte stride must be a multiple of 4 and between 4 and 252.")
			buffer_view_dict.erase("byteStride")


	if  "GOOGLE_camera_settings" or "GOOGLE_backgrounds" in extensions:
		has_google_extensions = true
	return OK

func _import_node(state, gltf_node, json, node):
	if has_google_extensions:
		if node is DirectionalLight3D:
			node.queue_free()
		if node is Camera3D:
			node.queue_free()
