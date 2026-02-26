@tool
class_name IcosaTiltGLTF
extends GLTFDocumentExtension

## GLTFDocumentExtension for Tilt Brush / Open Brush assets.
## Registered separately in plugin.gd alongside IcosaGLTF.

var material_cache: Dictionary = {}
var brush_materials: Dictionary = {}
var name_mapping: Dictionary = {}
var environment_data: Dictionary = {}
var _gltf_json_cache: Dictionary = {}

# Default Tilt Brush light rig used when the file doesn't specify lights.
const DEFAULT_LIGHT_0_DIRECTION := Vector3(0.0, -0.707, 0.707)
const DEFAULT_LIGHT_0_COLOR := Color(1.0, 0.99, 0.95, 1.0)
const DEFAULT_LIGHT_1_DIRECTION := Vector3(0.0, 0.5, -0.866)
const DEFAULT_LIGHT_1_COLOR := Color(0.35, 0.4, 0.55, 1.0)
const DEFAULT_AMBIENT_COLOR := Color(0.2, 0.2, 0.2, 1.0)


func _is_tilt_brush(gltf_state: GLTFState) -> bool:
	var json = gltf_state.json
	if not json is Dictionary:
		return false
	var asset = json.get("asset")
	if not asset is Dictionary:
		return false
	var generator: String = asset.get("generator", "")
	return generator.begins_with("Tilt Brush") or generator.begins_with("Open Brush")


func _get_gltf_json(gltf_state: GLTFState) -> Dictionary:
	if not _gltf_json_cache.is_empty():
		return _gltf_json_cache
	var json = gltf_state.json
	if json is Dictionary:
		return json
	return {}


func _import_preflight(gltf_state: GLTFState, extensions: PackedStringArray) -> Error:
	var gltf_json_variant := gltf_state.json
	if not (gltf_json_variant is Dictionary):
		return OK
	var gltf_json: Dictionary = gltf_json_variant

	var asset = gltf_json.get("asset")
	if not asset is Dictionary:
		return OK
	var generator: String = asset.get("generator", "")
	if not (generator.begins_with("Tilt Brush") or generator.begins_with("Open Brush")):
		return OK

	_ensure_loaded()
	_gltf_json_cache = gltf_json
	_patch_import_file(gltf_state)

	# Clear embedded image URIs — brush ShaderMaterials supply their own textures.
	# The URIs point to https:/www.tiltbrush.com/... which can't be loaded locally.
	if gltf_json.has("images"):
		gltf_json["images"] = []
	if gltf_json.has("textures"):
		gltf_json["textures"] = []

	# Clear material texture references — brush ShaderMaterials supply their own.
	if gltf_json.has("materials"):
		for material in gltf_json["materials"]:
			if not material is Dictionary:
				continue
			if material.has("pbrMetallicRoughness"):
				var pbr = material["pbrMetallicRoughness"]
				pbr.erase("baseColorTexture")
				pbr.erase("metallicRoughnessTexture")
			material.erase("normalTexture")
			material.erase("occlusionTexture")
			material.erase("emissiveTexture")
			if material.has("extensions"):
				material["extensions"].erase("GOOGLE_tilt_brush_material")

	_map_custom_attributes_to_standard_slots(gltf_json)

	# gltf_state.json returns a copy — write the modified dict back so Godot sees our changes.
	gltf_state.json = gltf_json

	return OK


func _import_post_parse(gltf_state: GLTFState) -> Error:
	if not _is_tilt_brush(gltf_state):
		return OK
	_ensure_loaded()
	var gltf_json := _get_gltf_json(gltf_state)
	_add_custom_data_to_brushes(gltf_state, gltf_json)
	return OK


func _import_post(gltf_state: GLTFState, root: Node) -> Error:
	if not _is_tilt_brush(gltf_state):
		return OK
	_ensure_loaded()
	var gltf_json := _get_gltf_json(gltf_state)
	_apply_lights(root, gltf_json)
	_apply_brush_materials_to_meshes(gltf_state)
	_rename_nodes(root)
	if ProjectSettings.get_setting("icosa/environment/import_tilt_brush_environment", false):
		_apply_environment(root, gltf_json)
	if ProjectSettings.get_setting("icosa/environment/import_world_environment", false):
		_apply_world_environment(root, gltf_json)
	_gltf_json_cache = {}
	return OK


func _apply_environment(root: Node, gltf_json: Dictionary) -> void:
	# Read environment GUID from scene extras.
	var scenes: Array = gltf_json.get("scenes", [])
	if scenes.is_empty():
		return
	var extras: Dictionary = scenes[0].get("extras", {})
	var env_guid: String = extras.get("TB_EnvironmentGuid", "")

	# Fall back to name-based lookup if GUID not present or not found.
	if env_guid.is_empty() or not environment_data.has(env_guid):
		var env_name: String = extras.get("TB_Environment", "")
		if not env_name.is_empty():
			for guid in environment_data:
				if environment_data[guid].get("name", "") == env_name:
					env_guid = guid
					break

	if env_guid.is_empty():
		return

	# Find the GLB inside the GUID-named folder.
	var env_dir := "res://addons/icosa/open_brush/environments/%s/" % env_guid
	var dir := DirAccess.open(env_dir)
	if dir == null:
		push_warning("IcosaTiltGLTF: environment folder not found: %s" % env_dir)
		return

	var glb_path := ""
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.get_extension().to_lower() == "glb":
			glb_path = env_dir + fname
			break
		fname = dir.get_next()
	dir.list_dir_end()

	if glb_path.is_empty():
		push_warning("IcosaTiltGLTF: no GLB found in environment folder: %s" % env_dir)
		return

	var env_scene: PackedScene = load(glb_path)
	if env_scene == null:
		push_warning("IcosaTiltGLTF: failed to load environment GLB: %s" % glb_path)
		return

	var env_node := env_scene.instantiate() as Node3D
	env_node.name = "TiltBrushEnvironment"
	env_node.scale = Vector3(0.1, 0.1, 0.1)
	env_node.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	root.add_child(env_node)
	env_node.owner = root


func _apply_world_environment(root: Node, gltf_json: Dictionary) -> void:
	# Resolve the environment GUID (same lookup as _apply_environment).
	var scenes: Array = gltf_json.get("scenes", [])
	if scenes.is_empty():
		return
	var extras: Dictionary = scenes[0].get("extras", {})
	var env_guid: String = extras.get("TB_EnvironmentGuid", "")

	if env_guid.is_empty() or not environment_data.has(env_guid):
		var env_name: String = extras.get("TB_Environment", "")
		if not env_name.is_empty():
			for guid in environment_data:
				if environment_data[guid].get("name", "") == env_name:
					env_guid = guid
					break

	if env_guid.is_empty() or not environment_data.has(env_guid):
		return

	var env_def: Dictionary = environment_data[env_guid]

	# Helper: convert {r,g,b,a} dict to Color.
	var c := func(d: Dictionary, fallback := Color.BLACK) -> Color:
		if d.is_empty():
			return fallback
		return Color(d.get("r", 0.0), d.get("g", 0.0), d.get("b", 0.0))

	# Helper: parse "r, g, b" string from GLTF extras into Color.
	var cs := func(s: String, fallback := Color.BLACK) -> Color:
		var parts := s.split(",")
		if parts.size() >= 3:
			return Color(parts[0].strip_edges().to_float(), parts[1].strip_edges().to_float(), parts[2].strip_edges().to_float())
		return fallback

	var rs: Dictionary = env_def.get("renderSettings", {})
	var clear: Dictionary = rs.get("clearColor", {})

	# GLTF extras carry per-sketch sky color overrides — prefer these over environments.json defaults.
	var sky_a: Color
	var sky_b: Color
	if extras.has("TB_SkyColorA"):
		sky_a = cs.call(extras["TB_SkyColorA"])
	else:
		sky_a = c.call(env_def.get("skyboxColorA", {}))
	if extras.has("TB_SkyColorB"):
		sky_b = cs.call(extras["TB_SkyColorB"])
	else:
		sky_b = c.call(env_def.get("skyboxColorB", {}))

	# TB_SkyGradientDirection is a world-space vector pointing toward sky_b.
	# Godot's ProceduralSkyMaterial only supports a vertical gradient.
	# If the gradient direction is close to straight up, map sky_a->horizon, sky_b->zenith.
	# Otherwise the gradient is off-axis and won't map well — use sky_b as a flat color.
	var use_gradient := false
	if extras.has("TB_SkyGradientDirection"):
		var parts := (extras["TB_SkyGradientDirection"] as String).split(",")
		if parts.size() >= 3:
			var dir := Vector3(parts[0].strip_edges().to_float(), parts[1].strip_edges().to_float(), parts[2].strip_edges().to_float()).normalized()
			use_gradient = dir.dot(Vector3.UP) > 0.7

	var sky_mat := ProceduralSkyMaterial.new()
	if use_gradient:
		sky_mat.sky_top_color = sky_b
		sky_mat.sky_horizon_color = sky_a
		sky_mat.ground_horizon_color = sky_a
		sky_mat.ground_bottom_color = sky_a
	else:
		sky_mat.sky_top_color = sky_b
		sky_mat.sky_horizon_color = sky_b
		sky_mat.ground_horizon_color = sky_b
		sky_mat.ground_bottom_color = sky_b
	sky_mat.sun_angle_max = 0.0
	sky_mat.sky_energy_multiplier = 1.0

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = c.call(rs.get("ambientColor", {}), Color(0.4, 0.4, 0.4))
	env.ambient_light_energy = 1.0
	env.fog_enabled = false

	var world_env := WorldEnvironment.new()
	world_env.name = "IcosaWorldEnvironment"
	world_env.environment = env
	root.add_child(world_env)
	world_env.owner = root


func _rename_nodes(root: Node) -> void:
	# Rename root node to OpenBrushScene.
	root.name = "OpenBrushScene"

	# GUID regex: 8-4-4-4-12 hex chars separated by hyphens.
	var guid_regex := RegEx.new()
	guid_regex.compile("[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")

	# Collect only the Node3D wrapper containers (not ImporterMeshInstance3D nodes).
	var containers := []
	for node in root.find_children("*", "", true, false):
		if (node.name as String).begins_with("node_") and node.get_class() == "Node3D":
			containers.append(node)

	# First pass: collect brush name per container and its mesh children.
	# brush_groups maps brush_name -> Array of {node, transform} to merge.
	var brush_groups: Dictionary = {}
	for container in containers:
		if not is_instance_valid(container):
			continue
		var node_name := container.name as String

		var brush_name := "Mesh"
		var m := guid_regex.search(node_name)
		if m != null:
			var mapped: String = name_mapping.get(m.get_string(), "")
			if not mapped.is_empty():
				brush_name = mapped

		var parent: Node = container.get_parent()
		if parent == null:
			continue

		for child in container.get_children():
			var child_xform := Transform3D.IDENTITY
			var child_node := child as Node3D
			if child_node != null:
				child_xform = container.transform * child_node.transform
			child.owner = null
			container.remove_child(child)
			if not brush_groups.has(brush_name):
				brush_groups[brush_name] = []
			brush_groups[brush_name].append({"node": child, "xform": child_xform})

		parent.remove_child(container)
		container.free()

	# Second pass: for each brush type, merge all ImporterMesh data into the first node
	# then discard the rest, or just place the single node directly.
	for brush_name in brush_groups:
		var entries: Array = brush_groups[brush_name]

		# Pull the primary node — use its ImporterMesh as the merge target.
		var primary_entry: Dictionary = entries[0]
		var primary_node: Node = primary_entry["node"]
		var primary_xform: Transform3D = primary_entry["xform"]
		var primary_mesh: ImporterMesh = primary_node.get("mesh") as ImporterMesh

		if primary_mesh == null:
			# Fallback: just hoist as-is.
			var pn3 := primary_node as Node3D
			if pn3:
				pn3.transform = primary_xform
			primary_node.owner = null
			root.add_child(primary_node)
			primary_node.owner = root
			primary_node.name = brush_name
			continue

		# Merge all subsequent meshes' surfaces into the primary ImporterMesh.
		var rel_to_primary := primary_xform.inverse()
		for i in range(1, entries.size()):
			var entry: Dictionary = entries[i]
			var other_node: Node = entry["node"]
			var other_xform: Transform3D = entry["xform"]
			var other_mesh: ImporterMesh = other_node.get("mesh") as ImporterMesh
			if other_mesh != null:
				var rel_xform := rel_to_primary * other_xform
				for s in range(other_mesh.get_surface_count()):
					var arrays := other_mesh.get_surface_arrays(s)
					# Transform vertex positions and normals into primary's local space.
					var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					for v in range(verts.size()):
						verts[v] = rel_xform * verts[v]
					arrays[Mesh.ARRAY_VERTEX] = verts
					if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
						var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
						var basis := rel_xform.basis.inverse().transposed()
						for v in range(normals.size()):
							normals[v] = (basis * normals[v]).normalized()
						arrays[Mesh.ARRAY_NORMAL] = normals
					primary_mesh.add_surface(
						other_mesh.get_surface_primitive_type(s),
						arrays, [], {},
						other_mesh.get_surface_material(s),
						other_mesh.get_surface_name(s)
					)
			other_node.free()

		# Place the merged primary node at the primary transform under root.
		var pn3 := primary_node as Node3D
		if pn3:
			pn3.transform = primary_xform
		primary_node.owner = null
		root.add_child(primary_node)
		primary_node.owner = root
		primary_node.name = brush_name


func _apply_brush_materials_to_meshes(gltf_state: GLTFState) -> void:
	# At _import_post time the scene still has ImporterMeshInstance3D nodes.
	# The ImporterMesh objects in GLTFState are the authoritative source —
	# set brush materials on them directly so they bake into the final ArrayMesh.
	var gltf_meshes := gltf_state.get_meshes()
	for gltf_mesh in gltf_meshes:
		var importer_mesh: ImporterMesh = gltf_mesh.mesh
		if importer_mesh == null:
			continue
		for i in range(importer_mesh.get_surface_count()):
			var mat: Material = importer_mesh.get_surface_material(i)
			if mat == null or mat.resource_name.is_empty():
				continue
			var brush_mat: Material = _find_matching_brush_material(mat.resource_name)
			if brush_mat != null:
				importer_mesh.set_surface_material(i, brush_mat)


func _patch_import_file(gltf_state: GLTFState) -> void:
	# Disable LOD generation in the .import file so Godot never builds LODs for Tilt Brush meshes.
	# If the file already has the correct value this is a no-op.
	var source := gltf_state.get_base_path().path_join(gltf_state.filename)
	var import_path := source + ".import"
	if not FileAccess.file_exists(import_path):
		return
	var file := FileAccess.open(import_path, FileAccess.READ)
	if file == null:
		return
	var content := file.get_as_text()
	file.close()
	if "meshes/generate_lods=false" in content:
		return  # already patched
	var patched := content.replace("meshes/generate_lods=true", "meshes/generate_lods=false")
	if patched == content:
		# Key not present at all — insert it after [params]
		patched = patched.replace("[params]\n", "[params]\nmeshes/generate_lods=false\n")
	var out := FileAccess.open(import_path, FileAccess.WRITE)
	if out == null:
		return
	out.store_string(patched)
	out.close()
	# Queue a reimport so the patched settings take effect on the next editor refresh.
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().reimport_files([source])


func _ensure_loaded() -> void:
	if brush_materials.is_empty():
		_scan_directory_for_materials("res://addons/icosa/open_brush/brush_materials/")
	if name_mapping.is_empty():
		var file := FileAccess.open("res://addons/icosa/open_brush/name_mapping.json", FileAccess.READ)
		if file != null:
			var parsed := JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				name_mapping = parsed
	if environment_data.is_empty():
		var file := FileAccess.open("res://addons/icosa/open_brush/environments/environments.json", FileAccess.READ)
		if file != null:
			var parsed := JSON.parse_string(file.get_as_text())
			file.close()
			if parsed is Dictionary:
				environment_data = parsed


func _scan_directory_for_materials(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var found_material_in_dir := false
	while file_name != "":
		var full_path := dir_path + file_name
		if dir.current_is_dir():
			_scan_directory_for_materials(full_path + "/")
		elif file_name.ends_with(".tres") and not found_material_in_dir:
			brush_materials[file_name.get_basename()] = full_path
			found_material_in_dir = true
		file_name = dir.get_next()



func _add_custom_data_to_brushes(gltf_state: GLTFState, gltf_json: Dictionary) -> void:
	var meshes := gltf_state.get_meshes()

	for mesh_idx in range(meshes.size()):
		var mesh = meshes[mesh_idx]
		var importer_mesh: ImporterMesh = mesh.mesh

		# Detect brush type by material name
		var brush_type := ""
		for surface_idx in range(importer_mesh.get_surface_count()):
			var mat := importer_mesh.get_surface_material(surface_idx)
			if mat != null:
				var mat_name := mat.resource_name
				if (mat_name.contains("Smoke") or mat_name.contains("Bubbles") or
						mat_name.contains("Dots") or mat_name.contains("Snow") or
						mat_name.contains("Stars") or mat_name.contains("Embers")):
					brush_type = "particle"
					break
				elif (mat_name.contains("Electricity") or
						mat_name.contains("DoubleTaperedMarker") or
						mat_name.contains("DoubleTaperedFlat") or
						mat_name.contains("HyperGrid")):
					brush_type = "ribbon"
					break

		if brush_type == "":
			continue

		# Collect all surface data
		var surfaces := []
		for surface_idx in range(importer_mesh.get_surface_count()):
			var arrays := importer_mesh.get_surface_arrays(surface_idx)
			var vertex_count: int = arrays[Mesh.ARRAY_VERTEX].size()

			var custom0 := PackedFloat32Array()
			custom0.resize(vertex_count * 4)

			if brush_type == "particle":
				var centers = arrays[Mesh.ARRAY_NORMAL]
				if centers == null:
					centers = PackedVector3Array()

				for i in range(vertex_count):
					var base := i * 4
					custom0[base] = float(i)
					var center := Vector3.ZERO
					if centers is PackedVector3Array and i < centers.size():
						center = centers[i]
					custom0[base + 1] = center.x
					custom0[base + 2] = center.y
					custom0[base + 3] = center.z

				arrays[Mesh.ARRAY_NORMAL] = null

				var tangents = arrays[Mesh.ARRAY_TANGENT]
				if tangents != null and tangents.size() >= 4:
					var tx: float = tangents[0]
					var ty: float = tangents[1]
					if tx >= 0.0 and tx <= 1.0 and ty >= 0.0 and ty <= 1.0:
						var new_tangents := PackedFloat32Array()
						new_tangents.resize(vertex_count * 4)
						for i in range(vertex_count):
							var base := i * 4
							new_tangents[base + 0] = 0.0
							new_tangents[base + 1] = 0.0
							new_tangents[base + 2] = tangents[base + 2]
							new_tangents[base + 3] = 1.0
						arrays[Mesh.ARRAY_TANGENT] = new_tangents

			elif brush_type == "ribbon":
				var ribbon_offsets := _extract_tb_unity_texcoord1(gltf_state, gltf_json, mesh_idx, surface_idx)

				for i in range(vertex_count):
					var base := i * 4
					custom0[base] = float(i)
					if i < ribbon_offsets.size():
						var offset := ribbon_offsets[i]
						custom0[base + 1] = offset.x
						custom0[base + 2] = offset.y
						custom0[base + 3] = offset.z
					else:
						custom0[base + 1] = 0.0
						custom0[base + 2] = 0.0
						custom0[base + 3] = 0.0

				arrays[Mesh.ARRAY_NORMAL] = null

			arrays[Mesh.ARRAY_CUSTOM0] = custom0

			surfaces.append({
				"primitive_type": importer_mesh.get_surface_primitive_type(surface_idx),
				"arrays": arrays,
				"material": importer_mesh.get_surface_material(surface_idx),
				"name": importer_mesh.get_surface_name(surface_idx)
			})

		var new_mesh := ImporterMesh.new()
		for i in range(surfaces.size()):
			var surface_data: Dictionary = surfaces[i]
			var original_material = surface_data["material"]
			var material_name: String = original_material.resource_name if original_material else ""
			var brush_material := _find_matching_brush_material(material_name)
			var final_material = brush_material if brush_material != null else original_material

			var format_flags := 0
			var arrays = surface_data["arrays"]
			if arrays[Mesh.ARRAY_VERTEX] != null:
				format_flags |= Mesh.ARRAY_FORMAT_VERTEX
			if arrays[Mesh.ARRAY_NORMAL] != null:
				format_flags |= Mesh.ARRAY_FORMAT_NORMAL
			if arrays[Mesh.ARRAY_TANGENT] != null:
				format_flags |= Mesh.ARRAY_FORMAT_TANGENT
			if arrays[Mesh.ARRAY_COLOR] != null:
				format_flags |= Mesh.ARRAY_FORMAT_COLOR
			if arrays[Mesh.ARRAY_TEX_UV] != null:
				format_flags |= Mesh.ARRAY_FORMAT_TEX_UV
			if arrays[Mesh.ARRAY_TEX_UV2] != null:
				format_flags |= Mesh.ARRAY_FORMAT_TEX_UV2
			if arrays[Mesh.ARRAY_INDEX] != null:
				format_flags |= Mesh.ARRAY_FORMAT_INDEX
			if arrays[Mesh.ARRAY_CUSTOM0] != null:
				format_flags |= (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)

			new_mesh.add_surface(
				surface_data["primitive_type"],
				arrays,
				[],
				{},
				final_material,
				surface_data["name"],
				format_flags
			)

		mesh.mesh = new_mesh


func _extract_tb_unity_texcoord1(gltf_state: GLTFState, gltf_json: Dictionary, mesh_idx: int, surface_idx: int) -> PackedVector3Array:
	if not gltf_json.has("meshes"):
		return PackedVector3Array()
	var meshes: Array = gltf_json.get("meshes", [])
	if mesh_idx >= meshes.size():
		return PackedVector3Array()
	var mesh = meshes[mesh_idx]
	var primitives: Array = mesh.get("primitives", [])
	if surface_idx >= primitives.size():
		return PackedVector3Array()
	var primitive: Dictionary = primitives[surface_idx]
	var attributes: Dictionary = primitive.get("attributes", {})
	if not attributes.has("_TB_UNITY_TEXCOORD_1"):
		return PackedVector3Array()

	var accessor_idx: int = attributes["_TB_UNITY_TEXCOORD_1"]
	var accessors: Array = gltf_json.get("accessors", [])
	if accessor_idx >= accessors.size():
		return PackedVector3Array()
	var accessor: Dictionary = accessors[accessor_idx]

	var buffer_view_idx = accessor.get("bufferView")
	var buffer_views: Array = gltf_json.get("bufferViews", [])
	if buffer_view_idx >= buffer_views.size():
		return PackedVector3Array()
	var buffer_view: Dictionary = buffer_views[buffer_view_idx]

	var buffer_idx: int = buffer_view.get("buffer", 0)
	var buffers: Array = gltf_json.get("buffers", [])
	if buffer_idx >= buffers.size():
		return PackedVector3Array()

	var buffer_info: Dictionary = buffers[buffer_idx]
	var buffer_uri: String = buffer_info.get("uri", "")
	var buffer_data: PackedByteArray

	if buffer_uri.is_empty():
		buffer_data = gltf_state.get_glb_data()
		if buffer_data.is_empty():
			return PackedVector3Array()
	else:
		var buffer_path := gltf_state.get_base_path().path_join(buffer_uri)
		var file := FileAccess.open(buffer_path, FileAccess.READ)
		if file == null:
			return PackedVector3Array()
		buffer_data = file.get_buffer(file.get_length())
		file.close()

	var byte_offset: int = accessor.get("byteOffset", 0) + buffer_view.get("byteOffset", 0)
	var count: int = accessor.get("count", 0)
	var byte_stride: int = buffer_view.get("byteStride", 12)

	var vec3_array := PackedVector3Array()
	vec3_array.resize(count)
	for i in range(count):
		var vertex_offset := byte_offset + (i * byte_stride)
		if vertex_offset + 12 > buffer_data.size():
			break
		var x := buffer_data.decode_float(vertex_offset)
		var y := buffer_data.decode_float(vertex_offset + 4)
		var z := buffer_data.decode_float(vertex_offset + 8)
		vec3_array[i] = Vector3(x, y, z)
	return vec3_array


func _apply_materials_to_importer_scene(node: Node, gltf_state: GLTFState) -> void:
	if node.get_class() == "ImporterMeshInstance3D":
		var importer_mesh = node.get("mesh")
		if importer_mesh != null:
			for i in range(importer_mesh.get_surface_count()):
				var current_mat = importer_mesh.get_surface_material(i)
				if current_mat != null and current_mat.resource_name != "":
					var brush_material := _find_matching_brush_material(current_mat.resource_name)
					if brush_material != null:
						importer_mesh.set_surface_material(i, brush_material)
	for child in node.get_children():
		_apply_materials_to_importer_scene(child, gltf_state)


func _find_matching_brush_material(material_name: String) -> Material:
	var original_name := material_name

	if material_name.begins_with("material_"):
		var parts := material_name.substr(9).split("-")
		if parts.size() >= 5:
			var guid := "-".join(parts.slice(parts.size() - 5, parts.size()))
			material_name = name_mapping.get(guid, material_name)
	elif material_name.begins_with("brush_"):
		material_name = material_name.substr(6)
	elif material_name.begins_with("ob-"):
		material_name = material_name.substr(3)

	if material_cache.has(original_name):
		return material_cache[original_name]

	if brush_materials.has(material_name):
		var loaded := load(brush_materials[material_name]) as Material
		if loaded != null:
			material_cache[original_name] = loaded
			return loaded

	var lower := material_name.to_lower()
	for brush_name in brush_materials.keys():
		if brush_name.to_lower() == lower:
			var loaded := load(brush_materials[brush_name]) as Material
			if loaded != null:
				material_cache[original_name] = loaded
				return loaded

	push_warning("IcosaTiltGLTF: no brush material for '%s' (mapped: '%s')" % [original_name, material_name])
	material_cache[original_name] = null
	return null


# ---------------------------------------------------------------------------
# Vertex attribute remapping
# ---------------------------------------------------------------------------

func _map_custom_attributes_to_standard_slots(gltf_json: Dictionary) -> void:
	if not gltf_json.has("meshes"):
		return

	var materials: Array = gltf_json.get("materials", [])
	var accessors: Array = gltf_json.get("accessors", [])
	var meshes: Array = gltf_json["meshes"]

	for mesh in meshes:
		if not mesh is Dictionary:
			continue
		for primitive in mesh.get("primitives", []):
			if not primitive is Dictionary:
				continue
			var attributes: Dictionary = primitive.get("attributes", {})

			var material_name := ""
			if primitive.has("material"):
				var mat_index: int = primitive["material"]
				if mat_index < materials.size() and materials[mat_index] is Dictionary:
					material_name = materials[mat_index].get("name", "")

			var is_particle_brush: bool = (
				material_name.contains("Smoke") or material_name.contains("Bubbles") or
				material_name.contains("Dots") or material_name.contains("Snow") or
				material_name.contains("Stars") or material_name.contains("Embers")
			)

			if is_particle_brush:
				if attributes.has("_TB_UNITY_NORMAL"):
					attributes["NORMAL"] = attributes["_TB_UNITY_NORMAL"]
					attributes.erase("_TB_UNITY_NORMAL")
				if attributes.has("_TB_UNITY_TEXCOORD_0"):
					attributes["TANGENT"] = attributes["_TB_UNITY_TEXCOORD_0"]
					attributes.erase("_TB_UNITY_TEXCOORD_0")
				elif attributes.has("TEXCOORD_0"):
					var texcoord_idx: int = attributes["TEXCOORD_0"]
					if texcoord_idx < accessors.size() and accessors[texcoord_idx].get("type") == "VEC4":
						# Split VEC4 TEXCOORD_0: VEC2 for UV, keep original as TANGENT
						var original_accessor: Dictionary = accessors[texcoord_idx]
						var uv_accessor := original_accessor.duplicate()
						uv_accessor["type"] = "VEC2"
						if uv_accessor.has("min") and uv_accessor["min"] is Array and uv_accessor["min"].size() >= 2:
							uv_accessor["min"] = [uv_accessor["min"][0], uv_accessor["min"][1]]
						if uv_accessor.has("max") and uv_accessor["max"] is Array and uv_accessor["max"].size() >= 2:
							uv_accessor["max"] = [uv_accessor["max"][0], uv_accessor["max"][1]]
						var uv_idx := accessors.size()
						var tangent_idx := accessors.size() + 1
						accessors.append(uv_accessor)
						accessors.append(original_accessor.duplicate())
						attributes["TEXCOORD_0"] = uv_idx
						attributes["TANGENT"] = tangent_idx
				if attributes.has("_TB_TIMESTAMP"):
					attributes["TEXCOORD_1"] = attributes["_TB_TIMESTAMP"]
					attributes.erase("_TB_TIMESTAMP")

			# Erase any TEXCOORD slot whose accessor is not VEC2 — Godot will error otherwise.
			for texcoord_key in ["TEXCOORD_0", "TEXCOORD_1", "TEXCOORD_2"]:
				if attributes.has(texcoord_key):
					var idx: int = attributes[texcoord_key]
					if idx < accessors.size() and accessors[idx].get("type") != "VEC2":
						attributes.erase(texcoord_key)

			# Erase VEC4 NORMAL — Godot expects VEC3.
			if attributes.has("NORMAL"):
				var normal_idx: int = attributes["NORMAL"]
				if normal_idx < accessors.size():
					if accessors[normal_idx].get("type") == "VEC4":
						attributes.erase("NORMAL")


# ---------------------------------------------------------------------------
# Lights
# ---------------------------------------------------------------------------

func _apply_lights(root: Node, gltf_json: Dictionary) -> void:
	var light_0_dir := DEFAULT_LIGHT_0_DIRECTION
	var light_0_col := DEFAULT_LIGHT_0_COLOR
	var light_1_dir := DEFAULT_LIGHT_1_DIRECTION
	var light_1_col := DEFAULT_LIGHT_1_COLOR
	var ambient_col := DEFAULT_AMBIENT_COLOR

	var parsed_lights := _parse_khr_lights(gltf_json)
	if parsed_lights.size() >= 1:
		light_0_dir = parsed_lights[0]["direction"]
		light_0_col = parsed_lights[0]["color"]
	if parsed_lights.size() >= 2:
		light_1_dir = parsed_lights[1]["direction"]
		light_1_col = parsed_lights[1]["color"]

	_replace_scene_light_nodes(root, light_0_col, light_1_col)
	_apply_light_uniforms_to_node(root, light_0_dir, light_0_col, light_1_dir, light_1_col, ambient_col)


func _replace_scene_light_nodes(root: Node,
		light_0_col: Color, light_1_col: Color) -> void:
	# Remove legacy light nodes that some file versions include.
	for node_name in ["keyLightNode", "headLightNode"]:
		for node in root.find_children(node_name, "", true, false):
			node.get_parent().remove_child(node)
			node.queue_free()

	# Replace node_SceneLight_* Node3D placeholders with DirectionalLight3D.
	var replacements := [
		["node_SceneLight_0", "u_SceneLight_0", light_0_col],
		["node_SceneLight_1", "u_SceneLight_1", light_1_col],
	]
	for entry in replacements:
		var prefix: String = entry[0]
		var new_name: String = entry[1]
		var col: Color = entry[2]
		for node in root.find_children("*", "", true, false):
			if not (node.name as String).begins_with(prefix):
				continue
			var light := DirectionalLight3D.new()
			light.name = new_name
			light.light_color = col
			light.transform = node.transform
			var parent := node.get_parent()
			parent.add_child(light)
			light.owner = root
			parent.remove_child(node)
			node.queue_free()

	# Rename Camera to ThumbnailCamera.
	for cam in root.find_children("Camera", "Camera3D", true, false):
		cam.name = "ThumbnailCamera"


func _parse_khr_lights(gltf_json: Dictionary) -> Array:
	var result: Array = []
	if not gltf_json.get("extensionsUsed", []).has("KHR_lights_punctual"):
		return result
	var lights_arr: Array = gltf_json.get("extensions", {}).get("KHR_lights_punctual", {}).get("lights", [])
	if lights_arr.is_empty():
		return result

	for node in gltf_json.get("nodes", []):
		if not node is Dictionary:
			continue
		var node_khr: Dictionary = node.get("extensions", {}).get("KHR_lights_punctual", {})
		if not node_khr.has("light"):
			continue
		var light_idx: int = node_khr["light"]
		if light_idx >= lights_arr.size():
			continue
		var light_def: Dictionary = lights_arr[light_idx]
		if light_def.get("type", "") != "directional":
			continue

		var direction := Vector3(0.0, -1.0, 0.0)
		if node.has("rotation"):
			var r: Array = node["rotation"]
			if r.size() == 4:
				direction = Quaternion(r[0], r[1], r[2], r[3]) * Vector3(0.0, 0.0, -1.0)

		var col := Color.WHITE
		var c: Array = light_def.get("color", [])
		if c.size() >= 3:
			col = Color(c[0], c[1], c[2], 1.0)
		col = col * light_def.get("intensity", 1.0)

		result.append({"direction": direction, "color": col})
		if result.size() >= 2:
			break

	return result


func _apply_light_uniforms_to_node(
		node: Node,
		light_0_dir: Vector3, light_0_col: Color,
		light_1_dir: Vector3, light_1_col: Color,
		ambient_col: Color) -> void:
	if node is MeshInstance3D:
		var mesh : Mesh = node.mesh
		if mesh != null:
			for i in range(mesh.get_surface_count()):
				var mat := mesh.surface_get_material(i)
				if mat is ShaderMaterial:
					_set_light_params(mat, light_0_dir, light_0_col, light_1_dir, light_1_col, ambient_col)
	for child in node.get_children():
		_apply_light_uniforms_to_node(child, light_0_dir, light_0_col, light_1_dir, light_1_col, ambient_col)


func _set_light_params(
		mat: ShaderMaterial,
		light_0_dir: Vector3, light_0_col: Color,
		light_1_dir: Vector3, light_1_col: Color,
		ambient_col: Color) -> void:
	var shader := mat.shader
	if shader == null:
		return
	var param_names: Array = RenderingServer.get_shader_parameter_list(shader.get_rid()).map(func(p): return p["name"])

	if "u_SceneLight_0_direction" in param_names:
		mat.set_shader_parameter("u_SceneLight_0_direction", light_0_dir)
	if "u_SceneLight_0_color" in param_names:
		mat.set_shader_parameter("u_SceneLight_0_color", light_0_col)
	if "u_SceneLight_1_direction" in param_names:
		mat.set_shader_parameter("u_SceneLight_1_direction", light_1_dir)
	if "u_SceneLight_1_color" in param_names:
		mat.set_shader_parameter("u_SceneLight_1_color", light_1_col)
	if "u_ambient_light_color" in param_names:
		mat.set_shader_parameter("u_ambient_light_color", ambient_col)
