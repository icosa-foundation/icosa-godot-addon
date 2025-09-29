@tool
class_name IcosaGLTF
extends GLTFDocumentExtension
#
#var has_google_extensions = false
#
### fixes a critical error that won't open certain gltf from icosa. 
#func _import_preflight(gltf_state: GLTFState, extensions: PackedStringArray) -> Error:
### written by aaronfranke. thank you!
	## HACK: This is workaround for an issue fixed in Godot 4.5.
	#var gltf_json: Dictionary = gltf_state.json
	#if not gltf_json.has("bufferViews"):
		#return OK
	#var buffer_views: Array = gltf_json["bufferViews"]
	#for i in range(buffer_views.size()):
		#var buffer_view_dict: Dictionary = buffer_views[i]
		#if not buffer_view_dict.has("byteStride"):
			#continue
		#var stride: int = buffer_view_dict["byteStride"]
		#if stride < 4 or stride > 252 or stride % 4 != 0:
			### error msg hidden from the user.
			##printerr("glTF import: Invalid byte stride " + str(stride) + " for buffer view at index " + str(i) + " while importing file '" + gltf_state.filename + "'. If defined, byte stride must be a multiple of 4 and between 4 and 252.")
			#buffer_view_dict.erase("byteStride")
#
	### check for uneeded lights and cameras.
	#if  "GOOGLE_camera_settings" or "GOOGLE_backgrounds" in extensions:
		#has_google_extensions = true
	#
	#
	#
	#
	#
	### aaronfranke patch #2, removing meshes
	#var asset = gltf_state.json.get("asset")
	#if not asset is Dictionary:
		#return ERR_SKIP
	#if asset.get("generator") != "Obj2GltfConverter":
		#return ERR_SKIP
	#var meshes = gltf_state.json.get("meshes")
	#if not meshes is Array or meshes.size() != 1:
		#return ERR_SKIP
	#if not (extensions.has("GOOGLE_backgrounds") and extensions.has("GOOGLE_camera_settings")):
		#return ERR_SKIP
	#var ext_used: Array = gltf_state.json["extensionsUsed"]
	#ext_used.append("GODOT_single_root")
	#return OK
#
#func _import_post_parse(gltf_state: GLTFState) -> Error:
	#var mesh_node := GLTFNode.new()
	#mesh_node.original_name = gltf_state.filename
	#mesh_node.resource_name = gltf_state.filename
	#mesh_node.mesh = 0
	#var nodes: Array[GLTFNode] = [mesh_node]
	#gltf_state.set_nodes(nodes)
	#gltf_state.root_nodes = PackedInt32Array([0])
	#return OK
