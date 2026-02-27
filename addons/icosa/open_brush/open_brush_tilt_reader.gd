@tool
class_name IcosaOpenBrushTiltReader

## Native .tilt binary file reader for Open Brush / Tilt Brush assets.
## Returns parsed metadata, strokes, and thumbnail from a .tilt file.

const TILT_SENTINEL := 0x546c6974   # "tilT" little-endian
const SKETCH_SENTINEL := 0xc576a5cd

# Stroke extension mask bits (matches Open Brush SketchReader.cs StrokeExtension enum)
const STROKE_EXT_FLAGS  := 0x1  # uint32 (4 bytes)
const STROKE_EXT_SCALE  := 0x2  # float  (4 bytes) — brush scale multiplier
const STROKE_EXT_GROUP  := 0x4  # uint32 (4 bytes)
const STROKE_EXT_SEED   := 0x8  # int32  (4 bytes)
const STROKE_EXT_LAYER  := 0x10 # uint32 (4 bytes)

# Control point extension mask bits
const CP_EXT_PRESSURE  := 0x1  # float (4 bytes)
const CP_EXT_TIMESTAMP := 0x2  # uint32 (4 bytes)


func load_tilt(path: String) -> Dictionary:
	var result := {
		"metadata": {},
		"strokes": [],
		"thumbnail": PackedByteArray(),
		"error": ""
	}

	# Validate .tilt header from the file directly.
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		result["error"] = "Cannot open file: %s (error %d)" % [path, FileAccess.get_open_error()]
		return result

	if not _read_header(file):
		file.close()
		result["error"] = "Invalid .tilt sentinel in: %s" % path
		return result
	file.close()

	# Extract ZIP contents (starts at byte 16).
	var zip_data := _read_zip_data(path)
	if zip_data.is_empty():
		result["error"] = "Failed to extract ZIP data from: %s" % path
		return result

	# Parse metadata.json.
	var metadata_json: String = zip_data.get("metadata_json", "")
	if metadata_json.is_empty():
		result["error"] = "metadata.json missing from: %s" % path
		return result
	var metadata := _parse_metadata(metadata_json)
	if metadata.is_empty():
		result["error"] = "Failed to parse metadata.json in: %s" % path
		return result
	result["metadata"] = metadata

	# Parse data.sketch.
	var sketch_data: PackedByteArray = zip_data.get("sketch_data", PackedByteArray())
	if sketch_data.is_empty():
		result["error"] = "data.sketch missing from: %s" % path
		return result

	var brush_index: Array = metadata.get("BrushIndex", [])
	var strokes := _parse_sketch(sketch_data, brush_index)
	result["strokes"] = strokes

	# Optional thumbnail.
	result["thumbnail"] = zip_data.get("thumbnail", PackedByteArray())

	return result


func _read_header(file: FileAccess) -> bool:
	if file.get_length() < 16:
		return false
	file.seek(0)
	var sentinel := file.get_32()
	# The file is little-endian; get_32 reads LE by default.
	return sentinel == TILT_SENTINEL


func _read_zip_data(path: String) -> Dictionary:
	# .tilt files are: 16-byte header + ZIP archive.
	# ZIPReader can only open a real file, so we extract the ZIP portion to a
	# temp file in user:// if the file doesn't open directly.
	# Strategy: try opening as-is first (ZIPReader searches for the end-of-central-directory
	# record from the back, so it should handle the 16-byte prefix automatically).
	var result := {}

	var zip := ZIPReader.new()
	var err := zip.open(ProjectSettings.globalize_path(path))

	if err != OK:
		# If it fails, extract the ZIP portion to a temp file.
		var src := FileAccess.open(path, FileAccess.READ)
		if src == null:
			return result
		src.seek(16)  # Skip 16-byte .tilt header
		var zip_bytes := src.get_buffer(src.get_length() - 16)
		src.close()

		var tmp_path := "user://_tilt_tmp.zip"
		var tmp := FileAccess.open(tmp_path, FileAccess.WRITE)
		if tmp == null:
			return result
		tmp.store_buffer(zip_bytes)
		tmp.close()

		err = zip.open(ProjectSettings.globalize_path(tmp_path))
		if err != OK:
			push_warning("IcosaOpenBrushTiltReader: ZIPReader failed to open %s (error %d)" % [path, err])
			return result

	var files := zip.get_files()

	for fname in files:
		var lower := (fname as String).to_lower()
		if lower == "metadata.json":
			var raw := zip.read_file(fname)
			result["metadata_json"] = raw.get_string_from_utf8()
		elif lower == "data.sketch":
			result["sketch_data"] = zip.read_file(fname)
		elif lower == "thumbnail.png":
			result["thumbnail"] = zip.read_file(fname)

	zip.close()
	return result


func _parse_metadata(json_text: String) -> Dictionary:
	var parsed := JSON.parse_string(json_text)
	if parsed is Dictionary:
		return parsed
	return {}


func _parse_sketch(data: PackedByteArray, brush_index: Array) -> Array:
	var buf := StreamPeerBuffer.new()
	buf.data_array = data
	buf.big_endian = false

	# Validate sketch sentinel.
	var sentinel := buf.get_u32()
	if sentinel != SKETCH_SENTINEL:
		push_warning("IcosaOpenBrushTiltReader: invalid sketch sentinel 0x%x" % sentinel)
		return []

	var version := buf.get_32()
	var _reserved := buf.get_32()
	var more_header_size := buf.get_u32()
	# Skip extra header bytes.
	if more_header_size > 0:
		buf.seek(buf.get_position() + more_header_size)

	var num_strokes := buf.get_32()
	if num_strokes <= 0:
		return []

	var strokes: Array = []
	strokes.resize(num_strokes)

	for i in range(num_strokes):
		var stroke := _parse_stroke(buf, version, brush_index)
		if stroke.is_empty():
			# Parsing error — stop early.
			push_warning("IcosaOpenBrushTiltReader: stroke %d parse failed, stopping." % i)
			break
		strokes[i] = stroke

	# Remove any trailing nulls from early stop.
	strokes = strokes.filter(func(s): return s != null and not s.is_empty())
	return strokes


func _parse_stroke(buf: StreamPeerBuffer, version: int, brush_index: Array) -> Dictionary:
	var stroke := {}

	var bi := buf.get_32()
	stroke["brush_index"] = bi

	# Version >= 6 can have inline GUIDs when brush_index == -1.
	if version >= 6 and bi == -1:
		var guid_bytes: PackedByteArray = buf.get_data(16)[1]
		stroke["brush_guid"] = _bytes_to_guid(guid_bytes)
	elif bi >= 0 and bi < brush_index.size():
		stroke["brush_guid"] = brush_index[bi]
	else:
		stroke["brush_guid"] = ""

	# RGBA color as 4 floats.
	var r := buf.get_float()
	var g := buf.get_float()
	var b := buf.get_float()
	var a := buf.get_float()
	stroke["color"] = Color(r, g, b, a)

	var brush_size := buf.get_float()

	var stroke_ext_mask := buf.get_u32()
	var cp_ext_mask := buf.get_u32()

	# Read stroke extension fields — must process every set bit to keep stream aligned.
	var brush_scale := 1.0
	var fields := stroke_ext_mask
	while fields != 0:
		var bit := fields & (~fields + 1)  # isolate lowest set bit
		match bit:
			STROKE_EXT_FLAGS: buf.get_u32()
			STROKE_EXT_SCALE: brush_scale = buf.get_float()
			STROKE_EXT_GROUP: buf.get_u32()
			STROKE_EXT_SEED:  buf.get_32()
			STROKE_EXT_LAYER: buf.get_u32()
			_:
				# Unknown single-word extension — skip 4 bytes.
				buf.get_u32()
		fields &= fields - 1  # clear lowest set bit

	stroke["brush_size"] = brush_size * brush_scale

	var num_cp := buf.get_32()
	if num_cp <= 0:
		stroke["control_points"] = []
		return stroke

	var control_points: Array = []
	control_points.resize(num_cp)
	for j in range(num_cp):
		control_points[j] = _parse_control_point(buf, cp_ext_mask)

	stroke["control_points"] = control_points
	return stroke


func _parse_control_point(buf: StreamPeerBuffer, cp_ext_mask: int) -> Dictionary:
	# Position: Unity left-hand → Godot right-hand: negate Z.
	var px := buf.get_float()
	var py := buf.get_float()
	var pz := buf.get_float()
	var position := Vector3(px, py, -pz)

	# Orientation quaternion (x, y, z, w): negate x and y for coord conversion.
	var qx := buf.get_float()
	var qy := buf.get_float()
	var qz := buf.get_float()
	var qw := buf.get_float()
	var orientation := Quaternion(-qx, -qy, qz, qw)

	var cp := {"position": position, "orientation": orientation}

	# Optional extensions.
	if cp_ext_mask & CP_EXT_PRESSURE:
		cp["pressure"] = buf.get_float()
	if cp_ext_mask & CP_EXT_TIMESTAMP:
		cp["timestamp"] = buf.get_u32()

	return cp



func _bytes_to_guid(bytes: PackedByteArray) -> String:
	# Convert 16 raw bytes to a UUID string (8-4-4-4-12 format), little-endian int fields.
	if bytes.size() < 16:
		return ""
	# .NET Guid layout: Data1(4 LE), Data2(2 LE), Data3(2 LE), Data4(8 bytes as-is)
	var d1 := "%02x%02x%02x%02x" % [bytes[3], bytes[2], bytes[1], bytes[0]]
	var d2 := "%02x%02x" % [bytes[5], bytes[4]]
	var d3 := "%02x%02x" % [bytes[7], bytes[6]]
	var d4 := "%02x%02x" % [bytes[8], bytes[9]]
	var d5 := "%02x%02x%02x%02x%02x%02x" % [bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]]
	return "%s-%s-%s-%s-%s" % [d1, d2, d3, d4, d5]
