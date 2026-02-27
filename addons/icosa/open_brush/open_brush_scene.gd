@tool
class_name IcosaOpenBrushScene
extends EditorSceneFormatImporter

## EditorSceneFormatImporter for Open Brush / Tilt Brush assets.
## Handles native .tilt binary files.
## For .gltf/.glb, import settings (LODs, shadow meshes) are patched via
## IcosaOpenBrushGLTF._patch_import_file(). This importer is .tilt only.

const _TiltReader = preload("res://addons/icosa/open_brush/open_brush_tilt_reader.gd")

var _open_brush: IcosaOpenBrush = null

func _get_open_brush() -> IcosaOpenBrush:
	if _open_brush == null:
		_open_brush = IcosaOpenBrush.new()
	return _open_brush


func _get_importer_name() -> String:
	return "icosa_open_brush"


func _get_extensions() -> PackedStringArray:
	return ["tilt"]


func _import_scene(path: String, flags: int, options: Dictionary) -> Object:
	var open_brush := _get_open_brush()
	open_brush.ensure_loaded()

	var reader := _TiltReader.new()
	var result: Dictionary = reader.load_tilt(path)
	if not result["error"].is_empty():
		push_error("IcosaOpenBrushScene: %s" % result["error"])
		return null
	return _build_scene(result)


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

	# Group strokes by brush name so we produce one MeshInstance3D per brush type.
	var brush_groups: Dictionary = {}  # brush_name -> Array of stroke dicts
	for stroke in strokes:
		var brush_name: String = ob.resolve_brush_name(stroke.get("brush_guid", ""))
		if not brush_groups.has(brush_name):
			brush_groups[brush_name] = []
		brush_groups[brush_name].append(stroke)

	# Build one merged MeshInstance3D per brush type.
	for brush_name in brush_groups:
		var mesh_instance := _build_brush_mesh(brush_name, brush_groups[brush_name], scene_scale)
		if mesh_instance != null:
			root.add_child(mesh_instance)
			mesh_instance.owner = root

	# Apply lights from environments.json (falls back to built-in defaults).
	var light_params: Dictionary = ob.extract_lights_from_env(resolved_env_guid)
	ob.apply_lights(
		root,
		light_params["light_0_dir"], light_params["light_0_col"],
		light_params["light_1_dir"], light_params["light_1_col"],
		light_params["ambient_col"])

	if ProjectSettings.get_setting("icosa/environment/import_tilt_brush_environment", false):
		ob.apply_environment(root, resolved_env_guid)

	if ProjectSettings.get_setting("icosa/environment/import_world_environment", false):
		ob.apply_world_environment(root, resolved_env_guid,
			Color(0, 0, 0, 0), Color(0, 0, 0, 0), Vector3.ZERO)

	return root


func _build_brush_mesh(brush_name: String, strokes: Array, scene_scale: float = 1.0) -> MeshInstance3D:
	if strokes.is_empty():
		return null

	var arrays := _tessellate_particle_strokes(strokes, scene_scale, brush_name) \
		if _is_particle_brush(brush_name) else \
		_tessellate_strokes(strokes, scene_scale, brush_name)
	var verts = arrays[Mesh.ARRAY_VERTEX]
	if verts == null or (verts as PackedVector3Array).is_empty():
		return null

	var arr_mesh := ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

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


# ---------------------------------------------------------------------------
# Particle tessellation — one billboard quad per control point
# ---------------------------------------------------------------------------

func _tessellate_particle_strokes(strokes: Array, scene_scale: float = 1.0, brush_name: String = "") -> Array:
	var verts   := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors  := PackedColorArray()
	var uvs     := PackedVector2Array()
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
		var brush_size: float = stroke.get("brush_size", 0.01) * scene_scale
		var half := brush_size * 0.5

		for cp in control_points:
			var pos: Vector3 = cp.get("position", Vector3.ZERO) * scene_scale
			var orient: Quaternion = cp.get("orientation", Quaternion.IDENTITY)
			# Quad spans the brush's local right and up axes.
			var right: Vector3 = orient * Vector3(1, 0, 0)
			var up: Vector3    = orient * Vector3(0, 1, 0)
			var normal: Vector3 = orient * Vector3(0, 0, -1)

			var base := verts.size()
			# v0=BL, v1=TL, v2=BR, v3=TR
			verts.append(pos - right * half - up * half)
			verts.append(pos - right * half + up * half)
			verts.append(pos + right * half - up * half)
			verts.append(pos + right * half + up * half)
			for _i in range(4):
				normals.append(normal)
				colors.append(color)

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
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR]  = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
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
		var brush_size: float = stroke.get("brush_size", 0.01) * scene_scale
		var half := brush_size * 0.5

		# Pick a random atlas row for this stroke — cycle through all rows evenly.
		var i_atlas := (stroke_idx * 3331) % atlas_v
		stroke_idx += 1
		var v0 := float(i_atlas) / float(atlas_v)
		var v1 := float(i_atlas + 1) / float(atlas_v)

		# Subdivide segments longer than spawn_interval to fill coverage gaps.
		control_points = _subdivide_control_points(control_points, brush_size)

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
