@tool
class_name IcosaOpenBrushScene
extends EditorSceneFormatImporter

## EditorSceneFormatImporter for Open Brush / Tilt Brush assets.
## Handles native .tilt binary files.
## For .gltf/.glb, import settings (LODs, shadow meshes) are patched via
## IcosaOpenBrushGLTF._patch_import_file(). This importer is .tilt only.

const _TiltReader = preload("res://addons/icosa/open_brush/open_brush_tilt_reader.gd")
const _ConcaveHullBrush = preload("res://Scripts/Brushes/ConcaveHullBrush.gd")
const _FlatGeometryBrush = preload("res://Scripts/Brushes/FlatGeometryBrush.gd")
const _HullBrush = preload("res://Scripts/Brushes/HullBrush.gd")
const _MeshData = preload("res://Scripts/Brushes/MeshData.gd")
const _QuadStripBrushDistanceUV = preload("res://Scripts/Brushes/QuadStripBrushDistanceUV.gd")
const _QuadStripBrushStretchUV = preload("res://Scripts/Brushes/QuadStripBrushStretchUV.gd")
const _TrTransform = preload("res://Scripts/TrTransform.gd")
const _UnityAssetLoader = preload("res://Scripts/UnityAssetLoader.gd")

var _open_brush: IcosaOpenBrush = null
var _brush_descriptor_cache: Dictionary = {}

func _get_open_brush() -> IcosaOpenBrush:
	if _open_brush == null:
		_open_brush = IcosaOpenBrush.new()
	return _open_brush


func _get_importer_name() -> String:
	return "icosa_open_brush"


func _get_extensions() -> PackedStringArray:
	return ["tilt"]


func _patch_tilt_import_file(path: String) -> void:
	var import_path := path + ".import"
	if not FileAccess.file_exists(import_path):
		return
	var file := FileAccess.open(import_path, FileAccess.READ)
	if file == null:
		return
	var content := file.get_as_text()
	file.close()
	if "meshes/generate_lods=false" in content and "meshes/create_shadow_meshes=false" in content:
		return  # already patched
	var patched := content
	patched = patched.replace("meshes/generate_lods=true", "meshes/generate_lods=false")
	patched = patched.replace("meshes/create_shadow_meshes=true", "meshes/create_shadow_meshes=false")
	var out := FileAccess.open(import_path, FileAccess.WRITE)
	if out == null:
		return
	out.store_string(patched)
	out.close()
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().reimport_files([path])


func _import_scene(path: String, flags: int, options: Dictionary) -> Object:
	_patch_tilt_import_file(path)
	var open_brush := _get_open_brush()
	open_brush.ensure_loaded()

	var start_ms := Time.get_ticks_msec()
	var reader := _TiltReader.new()
	var result: Dictionary = reader.load_tilt(path)
	if not result["error"].is_empty():
		push_error("IcosaOpenBrushScene: %s" % result["error"])
		return null
	var scene := _build_scene(result)
	if ProjectSettings.get_setting("icosa/debug/print_import_time", false):
		var elapsed := (Time.get_ticks_msec() - start_ms) / 1000.0
		print("[IcosaOpenBrushScene] Import took %.2f s — %s" % [elapsed, path.get_file()])
	return scene


# ---------------------------------------------------------------------------
# Scene construction
# ---------------------------------------------------------------------------

func _build_scene(tilt_data: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "TiltScene"

	var metadata: Dictionary = tilt_data.get("metadata", {})
	var strokes: Array = tilt_data.get("strokes", [])

	# SceneTransformInRoomSpace[2] is the scene scale (e.g. 0.1 means painted at 1/10 scale).
	# We apply it to positions and brush sizes so geometry matches the GLTF export scale.
	var scene_xf: Array = metadata.get("SceneTransformInRoomSpace", [])
	var scene_scale := 1.0
	if scene_xf.size() >= 3:
		scene_scale = float(scene_xf[2])
	if scene_scale <= 0.0:
		scene_scale = 1.0

	# Resolve environment GUID first — used for both lights and sky.
	# .tilt metadata stores EnvironmentPreset as a GUID string directly.
	var env_preset: String = metadata.get("EnvironmentPreset", "")
	var ob := _get_open_brush()
	var resolved_env_guid: String = ob.resolve_env_guid(env_preset, "")

	# Group most strokes by brush name so we produce one MeshInstance3D per brush type.
	# Runtime hull strokes are kept separate in source order because coplanar hull
	# surfaces can rely on stroke-level ordering.
	var brush_groups: Dictionary = {}  # brush_name -> Array of stroke dicts
	var hull_meshes: Array[MeshInstance3D] = []
	var hull_index := 0
	for stroke in strokes:
		var brush_name: String = ob.resolve_brush_name(stroke.get("brush_guid", ""))
		if _uses_runtime_hull_brush(brush_name):
			var hull_mesh := _build_brush_mesh(brush_name, [stroke], scene_scale)
			if hull_mesh != null:
				hull_mesh.name = "%s_%04d" % [brush_name, hull_index]
				hull_meshes.append(hull_mesh)
				hull_index += 1
			continue
		if not brush_groups.has(brush_name):
			brush_groups[brush_name] = []
		brush_groups[brush_name].append(stroke)

	# Build one merged MeshInstance3D per non-hull brush type.
	for brush_name in brush_groups:
		var mesh_instance := _build_brush_mesh(brush_name, brush_groups[brush_name], scene_scale)
		if mesh_instance != null:
			root.add_child(mesh_instance)
			mesh_instance.owner = root

	for hull_mesh in hull_meshes:
		root.add_child(hull_mesh)
		hull_mesh.owner = root

	# Apply lights from environments.json (falls back to built-in defaults).
	var light_params: Dictionary = ob.extract_lights_from_env(resolved_env_guid)
	ob.apply_lights(
		root,
		light_params["light_0_dir"], light_params["light_0_col"],
		light_params["light_1_dir"], light_params["light_1_col"],
		light_params["ambient_col"])

	if ProjectSettings.get_setting("icosa/import/import_tilt_brush_environment", false):
		ob.apply_environment(root, resolved_env_guid)

	if ProjectSettings.get_setting("icosa/import/import_world_environment", false):
		ob.apply_world_environment(root, resolved_env_guid,
			Color(0, 0, 0, 0), Color(0, 0, 0, 0), Vector3.ZERO)

	return root


func _build_brush_mesh(brush_name: String, strokes: Array, scene_scale: float = 1.0) -> MeshInstance3D:
	if strokes.is_empty():
		return null

	var arrays := _tessellate_runtime_flat_strokes(strokes, scene_scale, brush_name) \
		if _uses_runtime_flat_brush(brush_name) else []
	if arrays.is_empty() and _uses_runtime_quad_strip_brush(brush_name):
		arrays = _tessellate_runtime_quad_strip_strokes(strokes, scene_scale, brush_name)
	if arrays.is_empty() and _uses_runtime_hull_brush(brush_name):
		arrays = _tessellate_runtime_hull_strokes(strokes, scene_scale, brush_name)
	if arrays.is_empty():
		arrays = _tessellate_particle_strokes(strokes, scene_scale, brush_name) \
			if _is_particle_brush(brush_name) else \
			_tessellate_strokes(strokes, scene_scale, brush_name)
	var verts = arrays[Mesh.ARRAY_VERTEX]
	if verts == null or (verts as PackedVector3Array).is_empty():
		return null

	var arr_mesh := ArrayMesh.new()
	var format_flags := 0
	if arrays[Mesh.ARRAY_CUSTOM0] != null:
		format_flags |= (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format_flags)

	var mat: Material = _get_open_brush().find_matching_brush_material(brush_name)
	if mat != null:
		arr_mesh.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.name = brush_name
	mi.mesh = arr_mesh
	return mi


# Brushes that use one billboard quad per control point instead of a ribbon.
const PARTICLE_BRUSHES := [
	"Splatter", "Dots", "Bubbles", "Stars", "Snowflakes",
	"Embers", "Snow", "WigglyGraphite",
]

# Number of rows in the texture atlas per brush (m_TextureAtlasV).
# Brushes not listed default to 1 (full texture).
const BRUSH_ATLAS_V := {
	"CoarseBristles": 4, "Ink": 4, "Leaves": 4, "OilPaint": 4,
	"Smoke": 4, "Splatter": 4, "Stars": 4, "Taffy": 4,
	"VelvetInk": 4, "WetPaint": 4, "WigglyGraphite": 4,
}

# UV tiling rate along the stroke (m_TileRate).
# Brushes not listed default to 1.0 (stretch UV, u=0..1).
# A non-1.0 value means DistanceUV: u advances by TileRate * (segment_length / brush_size).
const BRUSH_TILE_RATE := {
	"CelVinyl": 0.2, "ChromaticWave": 0.1, "Disco": 0.15, "DotMarker": 1.0,
	"DoubleTaperedFlat": 0.1, "DoubleTaperedMarker": 0.1, "DuctTape": 0.6,
	"Electricity": 0.1, "FacetedTube": 0.15, "Icing": 0.25, "LightWire": 0.06,
	"Lofted": 0.2, "Marker": 0.15, "NeonPulse": 0.01, "Paper": 0.15,
	"Rainbow": 0.2, "Splatter": 0.2, "Streamers": 0.5, "Taffy": 1.0,
	"TaperedMarker": 0.15, "TaperedMarker_Flat": 0.15, "ThickPaint": 0.2,
	"Toon": 0.15, "TubeToonInverted": 0.15, "WaveformTube": 0.5,
	"WigglyGraphite": 0.1, "Wire": 0.15,
}

func _is_particle_brush(brush_name: String) -> bool:
	for name in PARTICLE_BRUSHES:
		if brush_name.to_lower() == name.to_lower():
			return true
	return false


func _uses_runtime_flat_brush(brush_name: String) -> bool:
	var descriptor := _load_brush_descriptor(brush_name)
	if descriptor == null:
		return false
	var prefab_name := str(descriptor.prefab_fields.get("prefab_name", ""))
	return prefab_name in ["FlatDistance", "FlatStretch"]


func _uses_runtime_quad_strip_brush(brush_name: String) -> bool:
	var descriptor := _load_brush_descriptor(brush_name)
	if descriptor == null:
		return false
	var prefab_name := str(descriptor.prefab_fields.get("prefab_name", ""))
	return prefab_name in ["DistanceUV", "Line"]


func _uses_runtime_hull_brush(brush_name: String) -> bool:
	return brush_name.ends_with("Hull")


func _load_brush_descriptor(brush_name: String) -> BrushDescriptor:
	if _brush_descriptor_cache.has(brush_name):
		return _brush_descriptor_cache[brush_name]
	var project_path := ProjectSettings.globalize_path("res://")
	var candidates := [
		project_path.path_join("Resources").path_join("Brushes").path_join("Basic").path_join(brush_name).path_join("%s.asset" % brush_name),
		project_path.path_join("Resources").path_join("X").path_join("Brushes").path_join(brush_name).path_join("%s.asset" % brush_name),
	]
	for path in candidates:
		var descriptor = _UnityAssetLoader.load_brush_descriptor(path)
		if descriptor != null:
			_brush_descriptor_cache[brush_name] = descriptor
			return descriptor
	_brush_descriptor_cache[brush_name] = null
	return null


func _tessellate_runtime_flat_strokes(strokes: Array, scene_scale: float = 1.0, brush_name: String = "") -> Array:
	var descriptor := _load_brush_descriptor(brush_name)
	if descriptor == null:
		return []

	var merged := _MeshData.new()
	for stroke in strokes:
		var control_points: Array = stroke.get("control_points", [])
		if control_points.size() < 2:
			continue

		var first_cp: Dictionary = control_points[0]
		var first_pos: Vector3 = first_cp.get("position", Vector3.ZERO) * scene_scale
		var first_orientation: Quaternion = first_cp.get("orientation", Quaternion.IDENTITY)
		var first_pressure := float(first_cp.get("pressure", 1.0))
		var stroke_scale := float(stroke.get("brush_scale", 1.0)) * scene_scale

		var brush = _FlatGeometryBrush.new()
		brush.m_BaseSize_PS = float(stroke.get("brush_size", 0.01))
		brush.m_Color = stroke.get("color", Color.WHITE)
		brush.set_random_seed(int(stroke.get("seed", 0)))
		brush.init_brush(descriptor, _TrTransform.trs(first_pos, first_orientation, stroke_scale))
		brush.set_random_seed(int(stroke.get("seed", 0)))

		for i in range(1, control_points.size()):
			var cp: Dictionary = control_points[i]
			var position: Vector3 = cp.get("position", Vector3.ZERO) * scene_scale
			var orientation: Quaternion = cp.get("orientation", Quaternion.IDENTITY)
			var pressure := float(cp.get("pressure", first_pressure))
			brush.update_position_ls(_TrTransform.trs(position, orientation, stroke_scale), pressure)

		brush.apply_changes_to_visuals()
		brush.finalize_solitary_brush()
		_append_mesh_data(merged, brush.mesh_data)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	if merged.vertices.is_empty() or merged.triangles.is_empty():
		return arrays
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(merged.vertices)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(merged.triangles)
	if merged.normals.size() == merged.vertices.size():
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(merged.normals)
	if merged.uv0_v2.size() == merged.vertices.size():
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(merged.uv0_v2)
	if merged.colors.size() == merged.vertices.size():
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray(merged.colors)
	if merged.tangents.size() == merged.vertices.size():
		var tangents := PackedFloat32Array()
		for tangent in merged.tangents:
			tangents.append(tangent.x)
			tangents.append(tangent.y)
			tangents.append(tangent.z)
			tangents.append(tangent.w)
		arrays[Mesh.ARRAY_TANGENT] = tangents
	return arrays


func _tessellate_runtime_quad_strip_strokes(strokes: Array, scene_scale: float = 1.0, brush_name: String = "") -> Array:
	var descriptor := _load_brush_descriptor(brush_name)
	if descriptor == null:
		return []

	var merged := _MeshData.new()
	var prefab_name := str(descriptor.prefab_fields.get("prefab_name", ""))
	for stroke in strokes:
		var control_points: Array = stroke.get("control_points", [])
		if control_points.size() < 2:
			continue

		var first_cp: Dictionary = control_points[0]
		var first_pos: Vector3 = first_cp.get("position", Vector3.ZERO) * scene_scale
		var first_orientation: Quaternion = first_cp.get("orientation", Quaternion.IDENTITY)
		var first_pressure := float(first_cp.get("pressure", 1.0))
		var stroke_scale := float(stroke.get("brush_scale", 1.0)) * scene_scale

		var brush
		if prefab_name == "DistanceUV":
			brush = _QuadStripBrushDistanceUV.new()
		else:
			brush = _QuadStripBrushStretchUV.new()
			brush.m_StoreWidthInTexcoord0Z = bool(descriptor.prefab_fields.get("m_StoreWidthInTexcoord0Z", brush.m_StoreWidthInTexcoord0Z))

		brush.m_BaseSize_PS = float(stroke.get("brush_size", 0.01))
		brush.m_Color = stroke.get("color", Color.WHITE)
		brush.set_random_seed(int(stroke.get("seed", 0)))
		brush.init_brush(descriptor, _TrTransform.trs(first_pos, first_orientation, stroke_scale))
		brush.set_random_seed(int(stroke.get("seed", 0)))

		for i in range(1, control_points.size()):
			var cp: Dictionary = control_points[i]
			var position: Vector3 = cp.get("position", Vector3.ZERO) * scene_scale
			var orientation: Quaternion = cp.get("orientation", Quaternion.IDENTITY)
			var pressure := float(cp.get("pressure", first_pressure))
			brush.update_position_ls(_TrTransform.trs(position, orientation, stroke_scale), pressure)

		brush.apply_changes_to_visuals()
		brush.finalize_solitary_brush()
		_append_mesh_data(merged, brush.mesh_data)

	return _mesh_data_to_arrays(merged)


func _tessellate_runtime_hull_strokes(strokes: Array, scene_scale: float = 1.0, brush_name: String = "") -> Array:
	var descriptor := _load_brush_descriptor(brush_name)
	if descriptor == null:
		return []

	var merged := _MeshData.new()
	for stroke in strokes:
		var control_points: Array = stroke.get("control_points", [])
		if control_points.size() < 2:
			continue

		var first_cp: Dictionary = control_points[0]
		var first_pos: Vector3 = first_cp.get("position", Vector3.ZERO) * scene_scale
		var first_orientation: Quaternion = first_cp.get("orientation", Quaternion.IDENTITY)
		var first_pressure := float(first_cp.get("pressure", 1.0))
		var stroke_scale := float(stroke.get("brush_scale", 1.0)) * scene_scale

		var brush = _ConcaveHullBrush.new() if brush_name == "ConcaveHull" else _HullBrush.new()
		brush.m_BaseSize_PS = float(stroke.get("brush_size", 0.01))
		brush.m_Color = stroke.get("color", Color.WHITE)
		brush.m_Faceted = bool(descriptor.prefab_fields.get("m_Faceted", brush.m_Faceted))
		if brush_name != "ConcaveHull":
			brush.m_TrackInterior = bool(descriptor.prefab_fields.get("m_TrackInterior", brush.m_TrackInterior))
			brush.m_Simplification_PS = float(descriptor.prefab_fields.get("m_Simplification_PS", brush.m_Simplification_PS))
			brush.m_SimplifyMode = int(descriptor.prefab_fields.get("m_SimplifyMode", brush.m_SimplifyMode))
		else:
			brush.m_KnotsInHull = int(descriptor.prefab_fields.get("m_KnotsInHull", brush.m_KnotsInHull))
		brush.m_KnotConversion = int(descriptor.prefab_fields.get("m_KnotConversion", brush.m_KnotConversion))
		brush.set_random_seed(int(stroke.get("seed", 0)))
		brush.init_brush(descriptor, _TrTransform.trs(first_pos, first_orientation, stroke_scale))
		brush.set_random_seed(int(stroke.get("seed", 0)))

		for i in range(1, control_points.size()):
			var cp: Dictionary = control_points[i]
			var position: Vector3 = cp.get("position", Vector3.ZERO) * scene_scale
			var orientation: Quaternion = cp.get("orientation", Quaternion.IDENTITY)
			var pressure := float(cp.get("pressure", first_pressure))
			brush.update_position_ls(_TrTransform.trs(position, orientation, stroke_scale), pressure)

		brush.apply_changes_to_visuals()
		brush.finalize_solitary_brush()
		_append_mesh_data(merged, brush.mesh_data)

	return _mesh_data_to_arrays(merged)


func _append_mesh_data(target: MeshData, source: MeshData) -> void:
	var vertex_offset := target.vertices.size()
	target.vertices.append_array(source.vertices)
	for tri in source.triangles:
		target.triangles.append(vertex_offset + tri)
	target.normals.append_array(source.normals)
	target.uv0_v2.append_array(source.uv0_v2)
	target.uv0_v3.append_array(source.uv0_v3)
	target.colors.append_array(source.colors)
	target.tangents.append_array(source.tangents)


func _mesh_data_to_arrays(mesh_data: MeshData) -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	if mesh_data.vertices.is_empty() or mesh_data.triangles.is_empty():
		return arrays
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(mesh_data.vertices)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(mesh_data.triangles)
	if mesh_data.normals.size() == mesh_data.vertices.size():
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(mesh_data.normals)
	if mesh_data.uv0_v2.size() == mesh_data.vertices.size():
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(mesh_data.uv0_v2)
	elif mesh_data.uv0_v3.size() == mesh_data.vertices.size():
		var uv2 := PackedVector2Array()
		for uv in mesh_data.uv0_v3:
			uv2.append(Vector2(uv.x, uv.y))
		arrays[Mesh.ARRAY_TEX_UV] = uv2
	if mesh_data.colors.size() == mesh_data.vertices.size():
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray(mesh_data.colors)
	if mesh_data.tangents.size() == mesh_data.vertices.size():
		var tangents := PackedFloat32Array()
		for tangent in mesh_data.tangents:
			tangents.append(tangent.x)
			tangents.append(tangent.y)
			tangents.append(tangent.z)
			tangents.append(tangent.w)
		arrays[Mesh.ARRAY_TANGENT] = tangents
	return arrays


# ---------------------------------------------------------------------------
# Particle tessellation — one billboard quad per control point
# ---------------------------------------------------------------------------

func _tessellate_particle_strokes(strokes: Array, scene_scale: float = 1.0, brush_name: String = "") -> Array:
	var verts   := PackedVector3Array()
	var colors  := PackedColorArray()
	var uvs     := PackedVector2Array()
	var tangents := PackedFloat32Array()
	var custom0 := PackedFloat32Array()
	var indices := PackedInt32Array()

	# Atlas V rows for this brush (Splatter, Stars, etc. use atlas=4).
	var brush_name_lower := brush_name.to_lower()
	var atlas_v := 1
	for k in BRUSH_ATLAS_V:
		if k.to_lower() == brush_name_lower:
			atlas_v = BRUSH_ATLAS_V[k]
			break

	# SprayBrush UV logic (Open Brush SprayBrush.cs OnChanged_UVs):
	# When atlas_v > 1: each quad randomly picks one of 4 quadrants of a 2×2 atlas.
	# The 4 base corners of the full texture are (0,0),(0.5,0),(0,0.5),(0.5,0.5).
	# A random offset from those same 4 values is added, giving one of 4 quadrant cells.
	# When atlas_v == 1: full texture (0..1 in both axes).
	# UV convention: BL=(0,0), FL=(1,0), BR=(0,1), FR=(1,1) within the cell.
	# Our vert order: v0=BL, v1=TL, v2=BR, v3=TR → matches BL,BR,FL,FR remapped.
	var offsets := [Vector2(0.0, 0.0), Vector2(0.5, 0.0), Vector2(0.0, 0.5), Vector2(0.5, 0.5)]

	var quad_idx := 0
	for stroke in strokes:
		var control_points: Array = stroke.get("control_points", [])
		var color: Color = stroke.get("color", Color.WHITE)
		var brush_size: float = stroke.get("brush_size", 0.01) * float(stroke.get("brush_scale", 1.0)) * scene_scale
		var half := brush_size * 0.5

		for cp in control_points:
			var pos: Vector3 = cp.get("position", Vector3.ZERO) * scene_scale
			var orient: Quaternion = cp.get("orientation", Quaternion.IDENTITY)
			# Quad spans the brush's local right and up axes.
			var right: Vector3 = orient * Vector3(1, 0, 0)
			var up: Vector3    = orient * Vector3(0, 1, 0)

			var base := verts.size()
			# v0=BL, v1=TL, v2=BR, v3=TR
			verts.append(pos - right * half - up * half)
			verts.append(pos - right * half + up * half)
			verts.append(pos + right * half - up * half)
			verts.append(pos + right * half + up * half)
			for vertex_offset in range(4):
				colors.append(color)
				tangents.append(0.0)
				tangents.append(0.0)
				tangents.append(0.0)
				tangents.append(1.0)
				custom0.append(float(base + vertex_offset))
				custom0.append(pos.x)
				custom0.append(pos.y)
				custom0.append(pos.z)

			if atlas_v > 1:
				# Pick random quadrant offset, cycling deterministically per CP.
				var off: Vector2 = offsets[quad_idx % 4]
				# BL=off+(0,0), TL=off+(0,0.5), BR=off+(0.5,0), TR=off+(0.5,0.5)
				uvs.append(off + Vector2(0.0, 0.0))  # BL (v0)
				uvs.append(off + Vector2(0.0, 0.5))  # TL (v1)
				uvs.append(off + Vector2(0.5, 0.0))  # BR (v2)
				uvs.append(off + Vector2(0.5, 0.5))  # TR (v3)
			else:
				uvs.append(Vector2(0.0, 0.0))
				uvs.append(Vector2(0.0, 1.0))
				uvs.append(Vector2(1.0, 0.0))
				uvs.append(Vector2(1.0, 1.0))
			quad_idx += 1

			# Winding: (v0,v3,v1), (v0,v2,v3)
			indices.append(base + 0); indices.append(base + 3); indices.append(base + 1)
			indices.append(base + 0); indices.append(base + 2); indices.append(base + 3)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	if verts.is_empty():
		return arrays
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR]  = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_CUSTOM0] = custom0
	arrays[Mesh.ARRAY_INDEX]  = indices
	return arrays


# ---------------------------------------------------------------------------
# Flat-ribbon tessellation matching Open Brush's ComputeSurfaceFrameNew
# ---------------------------------------------------------------------------

func _tessellate_strokes(strokes: Array, scene_scale: float = 1.0, brush_name: String = "") -> Array:
	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors  := PackedColorArray()
	var uvs     := PackedVector2Array()
	var indices := PackedInt32Array()

	var brush_name_lower := brush_name.to_lower()
	# Atlas V rows: how many rows in the texture atlas for this brush.
	var atlas_v := 1
	for k in BRUSH_ATLAS_V:
		if k.to_lower() == brush_name_lower:
			atlas_v = BRUSH_ATLAS_V[k]
			break
	# Tile rate: 1.0 = StretchUV (u=0..1 per stroke), other = DistanceUV (tiling).
	var tile_rate := 1.0
	for k in BRUSH_TILE_RATE:
		if k.to_lower() == brush_name_lower:
			tile_rate = BRUSH_TILE_RATE[k]
			break
	var use_distance_uv := (tile_rate != 1.0)

	var stroke_idx := 0
	for stroke in strokes:
		var control_points: Array = stroke.get("control_points", [])
		if control_points.size() < 2:
			stroke_idx += 1
			continue

		var color: Color = stroke.get("color", Color.WHITE)
		var brush_size: float = stroke.get("brush_size", 0.01) * float(stroke.get("brush_scale", 1.0)) * scene_scale
		var half := brush_size * 0.5

		# Pick a random atlas row for this stroke — cycle through all rows evenly.
		var i_atlas := (stroke_idx * 3331) % atlas_v
		stroke_idx += 1
		var v0 := float(i_atlas) / float(atlas_v)
		var v1 := float(i_atlas + 1) / float(atlas_v)

		# Subdivide segments longer than spawn_interval to fill coverage gaps.
		#control_points = _subdivide_control_points(control_points, brush_size)

		var lengths := _compute_arc_lengths(control_points, scene_scale)
		var total_len: float = lengths[-1] if lengths.size() > 0 else 1.0
		if total_len <= 0.0:
			total_len = 1.0

		var frames: Array = _compute_surface_frames(control_points)
		var n_cp := control_points.size()
		var base_idx := verts.size()

		# Build smoothed position + half-right at each knot (0.3/0.4/0.3 blend).
		# Matches Open Brush FlatGeometryBrush.OnChanged_MakeVertsAndNormals.
		var positions: Array = []
		var half_rights: Array = []
		for i in range(n_cp):
			var pos_c: Vector3 = control_points[i].get("position", Vector3.ZERO) * scene_scale
			var hr_c: Vector3  = frames[i]["right"] * half
			if i == 0 or i == n_cp - 1:
				positions.append(pos_c)
				half_rights.append(hr_c)
			else:
				var pos_p: Vector3 = control_points[i - 1].get("position", Vector3.ZERO) * scene_scale
				var pos_n: Vector3 = control_points[i + 1].get("position", Vector3.ZERO) * scene_scale
				var hr_p: Vector3  = frames[i - 1]["right"] * half
				var hr_n: Vector3  = frames[i + 1]["right"] * half
				positions.append(0.3 * pos_p + 0.4 * pos_c + 0.3 * pos_n)
				half_rights.append(0.3 * hr_p + 0.4 * hr_c + 0.3 * hr_n)

		for i in range(n_cp):
			var pos: Vector3    = positions[i]
			var hr: Vector3     = half_rights[i]
			var n_normal: Vector3 = frames[i]["normal"]
			var u: float
			if use_distance_uv:
				# DistanceUV: u advances by tile_rate * (length / brush_size).
				u = tile_rate * lengths[i] / brush_size if brush_size > 0.0 else 0.0
			else:
				# StretchUV: u stretches 0..1 across the whole stroke.
				u = lengths[i] / total_len

			verts.append(pos - hr)   # left  (v = v0)
			verts.append(pos + hr)   # right (v = v1)
			normals.append(n_normal)
			normals.append(n_normal)
			colors.append(color)
			colors.append(color)
			uvs.append(Vector2(u, v0))
			uvs.append(Vector2(u, v1))

		# Winding: BL=i0, BR=i1, FL=i2, FR=i3
		# Open Brush: tri0 = BR,BL,FL  tri1 = BR,FL,FR
		# → i1,i0,i2  and  i1,i2,i3
		for i in range(n_cp - 1):
			var i0 := base_idx + i * 2      # BL
			var i1 := i0 + 1                # BR
			var i2 := i0 + 2                # FL
			var i3 := i0 + 3                # FR
			indices.append(i1); indices.append(i0); indices.append(i2)
			indices.append(i1); indices.append(i2); indices.append(i3)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	if verts.is_empty():
		return arrays
	arrays[Mesh.ARRAY_VERTEX]  = verts
	arrays[Mesh.ARRAY_NORMAL]  = normals
	arrays[Mesh.ARRAY_COLOR]   = colors
	arrays[Mesh.ARRAY_TEX_UV]  = uvs
	arrays[Mesh.ARRAY_INDEX]   = indices
	return arrays


## Port of Open Brush BaseBrushScript.ComputeSurfaceFrameNew.
## Orientations are already in Godot space (reader: pos.z negated, quat.x quat.y negated).
func _compute_surface_frames(control_points: Array) -> Array:
	var n := control_points.size()

	# Pass 1: central-difference tangents (matches Open Brush non-M11 path).
	# Endpoints fall back to one-sided differences.
	var tangents: Array = []
	tangents.resize(n)
	var last_valid := Vector3(1, 0, 0)
	for i in range(n):
		var prev_pos: Vector3 = control_points[max(i - 1, 0)].get("position", Vector3.ZERO)
		var next_pos: Vector3 = control_points[min(i + 1, n - 1)].get("position", Vector3.ZERO)
		var t := next_pos - prev_pos
		if t.length_squared() > 1e-12:
			last_valid = t.normalized()
		tangents[i] = last_valid

	# Pass 2: ComputeSurfaceFrameNew per CP.
	# InDirectionOf flips each candidate to agree with prev_right before blending.
	# No extra negation — the coord conversion sign difference is absorbed by
	# the InDirectionOf alignment keeping prev_right consistent across frames.
	var frames: Array = []
	frames.resize(n)
	var prev_right := Vector3(1, 0, 0)
	for i in range(n):
		var orient: Quaternion = control_points[i].get("orientation", Quaternion.IDENTITY)
		var tangent: Vector3 = tangents[i]
		# Unity forward (0,0,1) → Godot -Z after coord conversion.
		var pf := orient * Vector3(0, 0, -1)
		var pu := orient * Vector3(0, 1,  0)
		var r1 := pf.cross(tangent)
		if r1.dot(prev_right) < 0.0: r1 = -r1
		var r2 := pu.cross(tangent) * absf(pf.dot(tangent))
		if r2.dot(prev_right) < 0.0: r2 = -r2
		var nr := r1 + r2
		nr = nr.normalized() if nr.length_squared() > 1e-12 else prev_right
		var nn := tangent.cross(nr)
		nn = nn.normalized() if nn.length_squared() > 1e-12 else Vector3(0, 1, 0)
		prev_right = nr
		frames[i] = {"right": nr, "normal": nn}

	return frames


## Subdivide a stroke's control points so no segment exceeds spawn_interval.
## Matches Open Brush's knot spawning: new knots are linearly interpolated in
## position and slerp'd in orientation.  brush_size is already scene-scaled.
const SUBDIVIDE_ASPECT_RATIO := 0.2   # kSolidAspectRatio
const SUBDIVIDE_MIN_INTERVAL := 0.001 # floor to avoid tiny brush_size explosion
const SUBDIVIDE_MAX_STEPS    := 8     # cap per segment — prevents runaway on coarse CP data

func _subdivide_control_points(control_points: Array, brush_size: float) -> Array:
	var interval := maxf(brush_size * SUBDIVIDE_ASPECT_RATIO, SUBDIVIDE_MIN_INTERVAL)

	var result: Array = []
	result.append(control_points[0])

	for i in range(1, control_points.size()):
		var prev_cp: Dictionary = control_points[i - 1]
		var curr_cp: Dictionary = control_points[i]
		var p0: Vector3    = prev_cp.get("position", Vector3.ZERO)
		var p1: Vector3    = curr_cp.get("position", Vector3.ZERO)

		var seg_len := p0.distance_to(p1)
		if seg_len > interval:
			var steps := mini(int(ceil(seg_len / interval)), SUBDIVIDE_MAX_STEPS)
			var q0: Quaternion = prev_cp.get("orientation", Quaternion.IDENTITY)
			var q1: Quaternion = curr_cp.get("orientation", Quaternion.IDENTITY)
			for s in range(1, steps):
				var t := float(s) / float(steps)
				result.append({
					"position":    p0.lerp(p1, t),
					"orientation": q0.slerp(q1, t),
				})

		result.append(curr_cp)

	return result


func _compute_arc_lengths(control_points: Array, scale: float = 1.0) -> PackedFloat32Array:
	var lengths := PackedFloat32Array()
	lengths.resize(control_points.size())
	lengths[0] = 0.0
	for i in range(1, control_points.size()):
		var prev: Vector3 = control_points[i - 1].get("position", Vector3.ZERO)
		var curr: Vector3 = control_points[i].get("position", Vector3.ZERO)
		lengths[i] = lengths[i - 1] + prev.distance_to(curr) * scale
	return lengths


# ---------------------------------------------------------------------------
# Metadata helpers
# ---------------------------------------------------------------------------
