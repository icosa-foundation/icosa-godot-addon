@tool
class_name IcosaGLTF
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

	## check for uneeded lights and cameras.
	if  "GOOGLE_camera_settings" or "GOOGLE_backgrounds" in extensions:
		has_google_extensions = true
		print("IGNORE BYTE STRIDE ERROR")
	return OK

var mesh_nodes = []

## remove any cameras and lights from the scene.
func _import_node(state: GLTFState, gltf_node: GLTFNode, json: Dictionary, node: Node) -> Error:
	if has_google_extensions:
		print("REMOVING JUNK DATA")
		if node is DirectionalLight3D or node is Camera3D:
			node.queue_free()
			return OK
	
	# Track mesh nodes for optimization
	if node is MeshInstance3D:
		mesh_nodes.append(node)
		
		# If node has a parent that's just an empty node (no mesh, no other children)
		var parent = node.get_parent()
		if parent and parent.get_child_count() == 1 and not (parent is MeshInstance3D):
			# Get the parent's transform
			var parent_transform = parent.transform
			# Apply parent's transform to mesh node
			node.transform = parent_transform * node.transform
			# Remove the empty parent
			parent.remove_child(node)
			parent.queue_free()
			
			# Add mesh directly to scene root
			var scene_root = state.get_scene_node(0)
			if scene_root:
				scene_root.add_child(node)
				node.owner = scene_root
	
	return OK

func _import_post_scene(state: GLTFState, scene: Node3D) -> Error:
	# If we have multiple mesh nodes, create a single container
	if mesh_nodes.size() > 1:
		var container = Node3D.new()
		container.name = "MeshContainer"
		scene.add_child(container)
		container.owner = scene
		
		# Move all mesh nodes under the container
		for mesh in mesh_nodes:
			if mesh.is_inside_tree():
				var old_parent = mesh.get_parent()
				old_parent.remove_child(mesh)
				container.add_child(mesh)
				mesh.owner = scene
				
				# Remove empty parent if it has no other children
				if old_parent and old_parent.get_child_count() == 0 and old_parent != scene:
					old_parent.queue_free()
	
	# Clear the mesh nodes array for next import
	mesh_nodes.clear()
	return OK

## also, we should get rid of everything but the mesh node, and if there are multiple meshes, add it to a single empty.
## currently the mesh is nested in 3 empties for some reason. would be goot to optimise.
