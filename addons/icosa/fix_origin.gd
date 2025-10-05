@tool
"""
This could be its own godot addon, very nice feature and shows how easy it is to add modal operations to godot
"""

class_name IcosaFixOriginTool
extends RefCounted

enum OriginMode {
	CENTER,    # Center the origin
	BOTTOM,    # Origin at bottom center
	TOP        # Origin at top center
}

var current_mode: OriginMode = OriginMode.CENTER

func set_mode(mode: OriginMode) -> void:
	current_mode = mode

func run_for_selection(editor_interface: EditorInterface) -> void:
	var selection := editor_interface.get_selection().get_selected_nodes()
	if selection.is_empty():
		_notify("Select one or more nodes to fix mesh origins.")
		return

	var fixed_count := 0
	for node in selection:
		fixed_count += _process_node_recursive(node, editor_interface)

	if fixed_count == 0:
		_notify("No MeshInstance3D nodes found in selection.")
	elif fixed_count == 1:
		_notify("Fixed 1 mesh origin (%s)." % _get_mode_name())
	else:
		_notify("Fixed %d mesh origins (%s)." % [fixed_count, _get_mode_name()])

func _process_node_recursive(node: Node, editor_interface: EditorInterface) -> int:
	var count := 0

	# Process this node if it's a MeshInstance3D
	if node is MeshInstance3D and node.mesh != null:
		_fix_mesh_origin(node, editor_interface)
		count += 1

	# Recursively process children
	for child in node.get_children():
		count += _process_node_recursive(child, editor_interface)

	return count

func _fix_mesh_origin(mesh_instance: MeshInstance3D, editor_interface: EditorInterface) -> void:
	var mesh_aabb: AABB = mesh_instance.mesh.get_aabb()
	
	# Calculate offset based on current mode
	var mesh_offset: Vector3
	match current_mode:
		OriginMode.CENTER:
			mesh_offset = mesh_aabb.position + mesh_aabb.size * 0.5
		OriginMode.BOTTOM:
			mesh_offset = Vector3(
				mesh_aabb.position.x + mesh_aabb.size.x * 0.5,
				mesh_aabb.position.y,  # Bottom of the mesh
				mesh_aabb.position.z + mesh_aabb.size.z * 0.5
			)
		OriginMode.TOP:
			mesh_offset = Vector3(
				mesh_aabb.position.x + mesh_aabb.size.x * 0.5,
				mesh_aabb.position.y + mesh_aabb.size.y,  # Top of the mesh
				mesh_aabb.position.z + mesh_aabb.size.z * 0.5
			)
	
	if mesh_offset.is_equal_approx(Vector3.ZERO):
		return

	var mesh := mesh_instance.mesh
	if not (mesh is ArrayMesh):
		_notify("Mesh type %s not supported for origin fix." % mesh.get_class())
		return

	var recentered := _recenter_array_mesh(mesh, -mesh_offset)
	if recentered == null:
		_notify("Failed to recenter mesh surfaces.")
		return

	recentered.resource_name = mesh.resource_name
	recentered.resource_local_to_scene = true
	var offset_in_parent := mesh_instance.transform.basis * mesh_offset
	var original_transform := mesh_instance.transform
	var new_transform := original_transform
	var original_position := mesh_instance.position
	new_transform.origin += offset_in_parent

	var undo: EditorUndoRedoManager = editor_interface.get_editor_undo_redo()
	if undo:
		undo.create_action("Fix Mesh Origin (%s)" % _get_mode_name())
		undo.add_do_property(mesh_instance, "mesh", recentered)
		undo.add_do_property(mesh_instance, "transform", new_transform)
		undo.add_do_property(mesh_instance, "position", Vector3(0,0,0))
		undo.add_undo_property(mesh_instance, "mesh", mesh)
		undo.add_undo_property(mesh_instance, "transform", original_transform)
		undo.add_undo_property(mesh_instance, "position", original_position)
		undo.commit_action()
	else:
		mesh_instance.mesh = recentered
		mesh_instance.transform = new_transform
		mesh_instance.position = Vector3(0,0,0)

func _recenter_array_mesh(mesh: ArrayMesh, translation: Vector3) -> ArrayMesh:
	var new_mesh := ArrayMesh.new()
	new_mesh.blend_shape_mode = mesh.blend_shape_mode
	for blend_shape_index in range(mesh.get_blend_shape_count()):
		new_mesh.add_blend_shape(mesh.get_blend_shape_name(blend_shape_index))

	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		if arrays.is_empty():
			continue
		if arrays.size() <= ArrayMesh.ARRAY_VERTEX:
			continue
		var verts: PackedVector3Array = arrays[ArrayMesh.ARRAY_VERTEX]
		if verts.is_empty():
			continue
		for i in range(verts.size()):
			verts[i] += translation
		arrays[ArrayMesh.ARRAY_VERTEX] = verts

		var blend_shapes := []
		var blend_shape_arrays := mesh.surface_get_blend_shape_arrays(surface)
		for blend_shape_index in range(blend_shape_arrays.size()):
			var blend_arrays: Array = blend_shape_arrays[blend_shape_index]
			if blend_arrays.size() <= ArrayMesh.ARRAY_VERTEX:
				continue
			var blend_vertices: PackedVector3Array = blend_arrays[ArrayMesh.ARRAY_VERTEX]
			for i in range(blend_vertices.size()):
				blend_vertices[i] += translation
			blend_arrays[ArrayMesh.ARRAY_VERTEX] = blend_vertices
			blend_shapes.append(blend_arrays)

		var primitive := mesh.surface_get_primitive_type(surface)
		var format := mesh.surface_get_format(surface)
		var new_surface_index := new_mesh.get_surface_count()
		var lods := {}
		new_mesh.add_surface_from_arrays(primitive, arrays, blend_shapes, lods, format)
		var material := mesh.surface_get_material(surface)
		if material:
			new_mesh.surface_set_material(new_surface_index, material)
		var surface_name := mesh.surface_get_name(surface)
		if surface_name != "":
			new_mesh.surface_set_name(new_surface_index, surface_name)

	if mesh.custom_aabb != AABB():
		var translated_aabb := mesh.custom_aabb
		translated_aabb.position += translation
		new_mesh.custom_aabb = translated_aabb

	return new_mesh

func _get_mode_name() -> String:
	match current_mode:
		OriginMode.CENTER:
			return "center"
		OriginMode.BOTTOM:
			return "bottom"
		OriginMode.TOP:
			return "top"
		_:
			return "unknown"

func _notify(message: String) -> void:
	print_rich("[color=yellow][Icosa Fix Origin][/color] %s" % message)
