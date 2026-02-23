@tool
class_name IcosaUploadStudio
extends Control

var browser  # Reference to the browser for accessing the token
var loaded_scene: Node3D  # The loaded scene for preview
var loaded_scene_path: String = ""  # Path to the loaded .tscn file
var editor_scene_root: Node  # Reference to the actual editor scene (for export)

func _init():
	#print("!!! [UploadStudio] _init called !!!")
	pass

func _ready():
	if Engine.is_editor_hint():
		return

	# Set up file dialog filters
	if has_node("%SceneFileDialog"):
		%SceneFileDialog.filters = PackedStringArray(["*.tscn ; Godot Scene Files"])

	# Set up SubViewportContainer to forward input to SubViewport for orbit controls
	var subviewport_container = %SubViewportContainer
	if subviewport_container:
		subviewport_container.set_process_input(true)
		subviewport_container.mouse_filter = Control.MOUSE_FILTER_PASS

func _on_background_color_color_changed(color):
	%WorldEnvironment.environment.background_color = color

func _on_snap_thumbnail_pressed():
	#print("[UploadStudio] Snap thumbnail button pressed!")
	var subviewport: SubViewport = %SubViewport
	var display: TextureRect = %ThumbnailDisplay
	subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	%SubViewportContainer.stretch = false
	%SubViewport.size = Vector2i(3840, 2160)
	await RenderingServer.frame_post_draw
	var viewport_texture: ViewportTexture = subviewport.get_texture()
	var image: Image = viewport_texture.get_image()
	var texture := ImageTexture.create_from_image(image)
	display.texture = texture
	subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	%SubViewportContainer.stretch = true

	#print("[UploadStudio] Thumbnail captured!")

	# Update file list to show thumbnail
	_update_file_list()
	
	
func _on_light_color_color_changed(color):
	%SceneLight1.light_color = color

func _on_ambient_light_color_color_changed(color):
	%SceneLight2.light_color = color

func _on_light_energy_value_changed(value):
	%SceneLight1.light_energy = value

func _on_ambient_light_energy_value_changed(value):
	%SceneLight2.light_energy = value

func _on_delete_thumbnail_pressed():
	%ThumbnailDisplay.texture = null
	_update_file_list()


func load_current_scene(scene_root: Node, scene_path: String):
	"""Load the currently edited scene from the editor"""
	#print("[UploadStudio] Loading current scene: ", scene_path)

	# Store reference to the actual editor scene (for export with materials)
	editor_scene_root = scene_root
	loaded_scene_path = scene_path

	# Clear existing preview scene
	if loaded_scene:
		loaded_scene.queue_free()
		loaded_scene = null

	# Duplicate for preview viewport only
	loaded_scene = scene_root.duplicate(DUPLICATE_USE_INSTANTIATION | DUPLICATE_SCRIPTS | DUPLICATE_SIGNALS) as Node3D
	if not loaded_scene:
		printerr("[UploadStudio] Failed to duplicate scene or scene is not a Node3D")
		_update_status("Error: Scene must be a Node3D")
		return

	# Add to the scene viewport for preview
	%Scene.add_child(loaded_scene)

	# Update file list
	_update_file_list()
	_update_status("Scene loaded: " + scene_path.get_file())

	#print("[UploadStudio] Scene loaded successfully")
	#print("[UploadStudio] Editor scene has %d children" % scene_root.get_child_count())

func _on_load_scene_pressed():
	#print("[UploadStudio] Load scene button pressed - opening file dialog")
	if has_node("%SceneFileDialog"):
		%SceneFileDialog.popup_centered_ratio(0.7)
	else:
		printerr("[UploadStudio] SceneFileDialog not found!")

func _on_scene_file_selected(path: String):
	_load_scene_from_file(path)

func _load_scene_from_file(path: String):
	"""Load a scene from a file path (manual selection)"""
	#print("[UploadStudio] Loading scene from file: ", path)

	# Clear existing scene
	if loaded_scene:
		loaded_scene.queue_free()
		loaded_scene = null

	# Load the scene
	var scene = load(path)
	if not scene:
		printerr("Failed to load scene: ", path)
		_update_status("Error: Failed to load scene")
		return

	# Instantiate it
	loaded_scene = scene.instantiate() as Node3D
	if not loaded_scene:
		printerr("Scene is not a Node3D: ", path)
		_update_status("Error: Scene must be a Node3D")
		return

	# Add to the scene viewport
	%Scene.add_child(loaded_scene)
	loaded_scene_path = path

	# Update file list
	_update_file_list()
	_update_status("Scene loaded: " + path.get_file())

	#print("Loaded scene: ", path)

func _update_file_list():
	if not has_node("%FileList"):
		return

	var tree: Tree = %FileList
	tree.clear()

	var root = tree.create_item()
	root.set_text(0, "Scene Files")

	if loaded_scene:
		var scene_item = tree.create_item(root)
		scene_item.set_text(0, loaded_scene_path.get_file())

	if %ThumbnailDisplay.texture:
		var thumb_item = tree.create_item(root)
		thumb_item.set_text(0, "thumbnail.png")

func _on_upload_pressed():
	if not browser:
		printerr("No browser reference - cannot upload")
		_update_status("Error: No browser reference")
		return

	if not browser.access_token or browser.access_token.is_empty():
		printerr("Not logged in - cannot upload")
		_update_status("Error: Not logged in. Please log in first.")
		return

	if not loaded_scene:
		printerr("No scene loaded - cannot upload")
		_update_status("Error: No scene loaded. Load a scene first.")
		return

	if not %ThumbnailDisplay.texture:
		printerr("No thumbnail captured - cannot upload")
		_update_status("Error: No thumbnail. Snap a thumbnail first.")
		return

	# Start the upload process
	_export_and_upload()

func _update_status(message: String):
	if has_node("%StatusLabel"):
		%StatusLabel.text = message

func _export_and_upload():
	#print("Starting export and upload process...")
	_update_status("Starting export...")

	# Create temporary directory for export
	var temp_dir = "user://icosa_upload_temp"
	var dir = DirAccess.open("user://")
	if dir.dir_exists("icosa_upload_temp"):
		# Clean up old temp directory
		_remove_dir_recursive(temp_dir)
	dir.make_dir("icosa_upload_temp")

	# Export scene as GLTF
	_update_status("Exporting scene to GLTF...")
	var gltf_path = temp_dir + "/scene.gltf"
	if not _export_scene_to_gltf(gltf_path):
		printerr("Failed to export scene to GLTF")
		_update_status("Error: Failed to export GLTF")
		return

	# Debug: List all files created by the export
	#print("[DEBUG] Files in temp directory after GLTF export:")
	_list_directory_recursive(temp_dir, "")

	# Save thumbnail
	_update_status("Saving thumbnail...")
	var thumbnail_path = temp_dir + "/thumbnail.png"
	if not _save_thumbnail(thumbnail_path):
		printerr("Failed to save thumbnail")
		_update_status("Error: Failed to save thumbnail")
		return

	# Create zip file
	_update_status("Creating zip file...")
	var zip_path = temp_dir + "/asset.zip"
	if not _create_zip(temp_dir, zip_path):
		printerr("Failed to create zip file")
		_update_status("Error: Failed to create zip")
		return

	# Verify the zip file was created and contains files
	#print("[VERIFY] Checking zip file before upload...")
	_verify_zip_contents(zip_path)

	# DEBUG: Copy zip to res:// for inspection
	#print("[DEBUG] Copying zip to res://debug_upload.zip for inspection...")
	var source_file = FileAccess.open(zip_path, FileAccess.READ)
	if source_file:
		var zip_data = source_file.get_buffer(source_file.get_length())
		source_file.close()

		var debug_file = FileAccess.open("res://debug_upload.zip", FileAccess.WRITE)
		if debug_file:
			debug_file.store_buffer(zip_data)
			debug_file.close()
			#print("[DEBUG] Saved copy to res://debug_upload.zip")

	# Upload the zip
	_update_status("Uploading to Icosa Gallery...")
	await _upload_zip(zip_path)

	# Clean up temp directory
	_remove_dir_recursive(temp_dir)

func _export_scene_to_gltf(output_path: String) -> bool:
	if not loaded_scene_path or loaded_scene_path.is_empty():
		printerr("No scene path available to export")
		return false

	var packed_scene = load(loaded_scene_path) as PackedScene
	if not packed_scene:
		printerr("Failed to load scene from: ", loaded_scene_path)
		return false

	var scene_to_export = packed_scene.instantiate() as Node3D
	if not scene_to_export:
		printerr("Failed to instantiate scene")
		return false

	_bake_override_materials(scene_to_export)

	var temp_textures_dir = output_path.get_base_dir() + "/temp_textures"
	var dir = DirAccess.open(output_path.get_base_dir())
	if dir and not dir.dir_exists("temp_textures"):
		dir.make_dir("temp_textures")

	_presave_textures_with_unique_names(scene_to_export, temp_textures_dir)

	var gltf_document = GLTFDocument.new()
	var gltf_state = GLTFState.new()

	gltf_document.image_format = "PNG"
	gltf_document.lossy_quality = 0.75

	gltf_state.set_base_path(output_path.get_base_dir())

	var error = gltf_document.append_from_scene(scene_to_export, gltf_state)
	if error != OK:
		printerr("Failed to convert scene to GLTF state: ", error)
		scene_to_export.queue_free()
		return false

	error = gltf_document.write_to_filesystem(gltf_state, output_path)
	if error != OK:
		printerr("Failed to write GLTF to file: ", error)
		scene_to_export.queue_free()
		return false

	_fix_gltf_uri_encoding(output_path)

	scene_to_export.queue_free()

	if DirAccess.dir_exists_absolute(temp_textures_dir):
		_remove_dir_recursive(temp_textures_dir)

	return true


func _count_materials_recursive(node: Node, count: int) -> int:
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		var mesh = mesh_instance.mesh
		if mesh:
			for i in range(mesh.get_surface_count()):
				# Check both override material and mesh material
				var override_mat = mesh_instance.get_surface_override_material(i)
				var mesh_mat = mesh.surface_get_material(i)
				var mat = override_mat if override_mat else mesh_mat

				if mat:
					count += 1
					var mat_type = mat.get_class()
					var is_standard = mat is StandardMaterial3D
					var is_override = override_mat != null

					# Check for textures
					var has_textures = false
					var texture_info = ""
					if is_standard:
						var std_mat = mat as StandardMaterial3D
						if std_mat.albedo_texture:
							has_textures = true
							texture_info += "albedo"
						if std_mat.normal_texture:
							has_textures = true
							texture_info += (", " if not texture_info.is_empty() else "") + "normal"
						if std_mat.metallic_texture:
							has_textures = true
							texture_info += (", " if not texture_info.is_empty() else "") + "metallic"
						if std_mat.roughness_texture:
							has_textures = true
							texture_info += (", " if not texture_info.is_empty() else "") + "roughness"

					#print("    Found material on %s surface %d: %s (type: %s, is StandardMaterial3D: %s, is override: %s, textures: %s)" % [
						#node.name, i,
						#mat.resource_name if mat.resource_name else "unnamed",
						#mat_type,
						#is_standard,
						#is_override,
						#texture_info if has_textures else "none"
					#])

	for child in node.get_children():
		count = _count_materials_recursive(child, count)

	return count

func _presave_textures_with_unique_names(node: Node, temp_dir: String):
	"""Pre-save all textures to temp directory with unique names, then reload them"""
	var texture_map = {}  # Original texture -> new texture path
	_collect_and_save_textures(node, temp_dir, texture_map)
	#print("    Pre-saved ", texture_map.size(), " unique textures")

	# Now replace the textures in materials with reloaded versions
	_replace_textures_with_presaved(node, texture_map)

func _collect_and_save_textures(node: Node, temp_dir: String, texture_map: Dictionary):
	"""Recursively collect and save all unique textures"""
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		var mesh = mesh_instance.mesh
		if mesh:
			for i in range(mesh.get_surface_count()):
				var mat = mesh.surface_get_material(i)
				if mat and mat is StandardMaterial3D:
					var std_mat = mat as StandardMaterial3D
					_save_texture_to_temp(std_mat.albedo_texture, temp_dir, texture_map)
					_save_texture_to_temp(std_mat.normal_texture, temp_dir, texture_map)
					_save_texture_to_temp(std_mat.metallic_texture, temp_dir, texture_map)
					_save_texture_to_temp(std_mat.roughness_texture, temp_dir, texture_map)

	for child in node.get_children():
		_collect_and_save_textures(child, temp_dir, texture_map)

func _save_texture_to_temp(texture: Texture2D, temp_dir: String, texture_map: Dictionary):
	"""Save a texture to temp directory with a unique name"""
	if not texture or texture_map.has(texture):
		return

	# Determine unique filename
	var texture_name = ""
	if texture.resource_path and not texture.resource_path.is_empty():
		texture_name = texture.resource_path.get_file().get_basename()
	else:
		texture_name = "texture_" + str(texture_map.size())

	# Make sure the name is unique
	var base_name = texture_name
	var counter = 0
	while texture_map.values().has(temp_dir + "/" + texture_name + ".png"):
		counter += 1
		texture_name = base_name + "_" + str(counter)

	var save_path = temp_dir + "/" + texture_name + ".png"

	# Get the image from the texture
	var image: Image = null
	if texture.has_method("get_image"):
		image = texture.get_image()

	if image:
		var err = image.save_png(save_path)
		if err == OK:
			texture_map[texture] = save_path
			#print("      Saved texture: ", texture_name, ".png")
		else:
			printerr("      Failed to save texture: ", err)


func _replace_textures_with_presaved(node: Node, texture_map: Dictionary):
	"""Replace textures in materials with reloaded versions from temp files"""
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		var mesh = mesh_instance.mesh
		if mesh:
			# Need to duplicate the mesh to modify materials
			var new_mesh = mesh.duplicate(true)
			for i in range(new_mesh.get_surface_count()):
				var mat = new_mesh.surface_get_material(i)
				if mat and mat is StandardMaterial3D:
					# Duplicate the material
					var new_mat = mat.duplicate() as StandardMaterial3D
					_replace_material_texture(new_mat, "albedo_texture", texture_map)
					_replace_material_texture(new_mat, "normal_texture", texture_map)
					_replace_material_texture(new_mat, "metallic_texture", texture_map)
					_replace_material_texture(new_mat, "roughness_texture", texture_map)
					new_mesh.surface_set_material(i, new_mat)
			# Set the mesh after processing all surfaces
			mesh_instance.mesh = new_mesh

	for child in node.get_children():
		_replace_textures_with_presaved(child, texture_map)

func _replace_material_texture(mat: StandardMaterial3D, texture_property: String, texture_map: Dictionary):
	"""Replace a texture property in a material with the pre-saved version"""
	var old_texture = mat.get(texture_property)
	if old_texture and texture_map.has(old_texture):
		var new_path = texture_map[old_texture]

		# Load the image from the temp file and create a new ImageTexture
		var file = FileAccess.open(new_path, FileAccess.READ)
		if file:
			var image = Image.new()
			var err = image.load_png_from_buffer(file.get_buffer(file.get_length()))
			file.close()

			if err == OK:
				var new_texture = ImageTexture.create_from_image(image)
				# CRITICAL: Set resource_path so GLTF exporter knows the filename
				new_texture.resource_path = new_path
				mat.set(texture_property, new_texture)
				#print("      Replaced ", texture_property, " with ", new_path.get_file())

func _bake_override_materials(node: Node):
	"""Bake surface override materials into the mesh resource so GLTF exporter can see them"""
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		var mesh = mesh_instance.mesh
		if mesh:
			# Check if any surfaces have override materials
			var has_overrides = false
			for i in range(mesh.get_surface_count()):
				if mesh_instance.get_surface_override_material(i):
					has_overrides = true
					break

			if has_overrides:
				# Duplicate the mesh so we don't modify the original resource
				var new_mesh = mesh.duplicate(true)

				# Apply all override materials to the mesh surfaces
				for i in range(new_mesh.get_surface_count()):
					var override_mat = mesh_instance.get_surface_override_material(i)
					if override_mat:
						new_mesh.surface_set_material(i, override_mat)
						#print("    Baked override material on %s surface %d: %s" % [
							#node.name, i,
							#override_mat.resource_name if override_mat.resource_name else "unnamed"
						#])

				# Replace the mesh on the instance
				mesh_instance.mesh = new_mesh

	# Recursively process children
	for child in node.get_children():
		_bake_override_materials(child)

func _save_thumbnail(output_path: String) -> bool:
	var texture = %ThumbnailDisplay.texture as ImageTexture
	if not texture:
		return false

	var image = texture.get_image()
	if not image:
		return false

	var error = image.save_png(output_path)
	if error != OK:
		printerr("Failed to save thumbnail: ", error)
		return false

	#print("Saved thumbnail to: ", output_path)
	return true

func _create_zip(source_dir: String, zip_path: String) -> bool:
	var packer = ZIPPacker.new()
	var error = packer.open(zip_path)
	if error != OK:
		printerr("Failed to create zip file: ", error)
		return false

	# Recursively add all files from the source directory
	var files_added = _add_directory_to_zip(packer, source_dir, "", zip_path.get_file())

	packer.close()

	#print("Created zip file with %d files: %s" % [files_added, zip_path])
	return files_added > 0

func _add_directory_to_zip(packer: ZIPPacker, dir_path: String, zip_prefix: String, skip_file: String) -> int:
	"""Recursively add all files from a directory to a zip archive"""
	var files_added = 0
	var dir = DirAccess.open(dir_path)
	if not dir:
		printerr("Failed to open directory: ", dir_path)
		return 0

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name != "." and file_name != ".." and file_name != skip_file:
			var full_path = dir_path + "/" + file_name
			var zip_path = zip_prefix + file_name if zip_prefix.is_empty() else zip_prefix + "/" + file_name

			if dir.current_is_dir():
				# Add directory entry to zip (required for proper structure)
				packer.start_file(zip_path + "/")
				packer.close_file()
				#print("  Added directory to zip: ", zip_path + "/")

				# Recursively add subdirectory contents
				files_added += _add_directory_to_zip(packer, full_path, zip_path, skip_file)
			else:
				# Add file to zip
				var file = FileAccess.open(full_path, FileAccess.READ)
				if file:
					packer.start_file(zip_path)
					packer.write_file(file.get_buffer(file.get_length()))
					packer.close_file()
					file.close()
					files_added += 1
					#print("  Added to zip: ", zip_path)
				else:
					printerr("  Failed to read file: ", full_path)

		file_name = dir.get_next()

	dir.list_dir_end()
	return files_added

func _verify_zip_contents(zip_path: String):
	"""Verify the zip file contains the expected files"""
	var reader = ZIPReader.new()
	var err = reader.open(zip_path)
	if err != OK:
		printerr("[VERIFY] Failed to open zip file: ", err)
		return

	var files = reader.get_files()
	#print("[VERIFY] Zip contains ", files.size(), " entries:")
	for file in files:
		var file_data = reader.read_file(file)
		#print("[VERIFY]   ", file, " (", file_data.size(), " bytes)")

	reader.close()

func _upload_zip(zip_path: String):
	const UPLOAD_ENDPOINT = "https://api.icosa.gallery/v1/users/me/assets"
	const HEADER_AGENT = "User-Agent: Icosa Gallery Godot Engine / 1.0"
	const HEADER_APP = "accept: application/json"
	const HEADER_AUTH = "Authorization: Bearer %s"

	# Read the zip file
	var file = FileAccess.open(zip_path, FileAccess.READ)
	if not file:
		printerr("Could not open zip file: ", zip_path)
		return

	var file_bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()

	# Create HTTP request
	var upload_http = HTTPRequest.new()
	add_child(upload_http)

	# Create multipart form data
	var boundary = "----GodotFormBoundary" + str(Time.get_ticks_msec())
	var body = PackedByteArray()
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array(("Content-Disposition: form-data; name=\"files\"; filename=\"asset.zip\"\r\n").to_utf8_buffer())
	body.append_array("Content-Type: application/zip\r\n\r\n".to_utf8_buffer())
	body.append_array(file_bytes)
	body.append_array("\r\n".to_utf8_buffer())
	body.append_array(("--" + boundary + "--\r\n").to_utf8_buffer())

	# Send request
	var err = upload_http.request_raw(
		UPLOAD_ENDPOINT,
		[HEADER_AGENT, HEADER_APP, HEADER_AUTH % browser.access_token, "Content-Type: multipart/form-data; boundary=" + boundary],
		HTTPClient.METHOD_POST,
		body
	)

	if err != OK:
		printerr("Failed to send upload request: ", err)
		upload_http.queue_free()
		return

	#print("Uploading asset...")

	# Wait for response
	var reply = await upload_http.request_completed
	var result = reply[0]
	var response_code = reply[1]
	var headers = reply[2]
	var response_body = reply[3]

	upload_http.queue_free()

	if response_code == 200 or response_code == 201:
		#print("Successfully uploaded asset!")
		#print("Response: ", response_body.get_string_from_utf8())
		_update_status("Success! Asset uploaded to Icosa Gallery")
	else:
		printerr("Upload error: ", response_code, " ", result)
		#print("Response body: ", response_body.get_string_from_utf8())
		_update_status("Error: Upload failed (code %d)" % response_code)

func _fix_gltf_uri_encoding(gltf_path: String):
	"""Fix URL-encoded URIs in GLTF JSON (textures%2Ffile.png -> textures/file.png)"""
	#print("  Fixing URI encoding in GLTF...")

	var gltf_file = FileAccess.open(gltf_path, FileAccess.READ)
	if not gltf_file:
		printerr("    Failed to open GLTF for URI fixing")
		return

	var gltf_json_text = gltf_file.get_as_text()
	gltf_file.close()

	var json = JSON.new()
	if json.parse(gltf_json_text) != OK:
		printerr("    Failed to parse GLTF JSON")
		return

	var gltf_data = json.data
	if not gltf_data is Dictionary or not gltf_data.has("images"):
		return

	# Fix the URIs in all images
	var images = gltf_data["images"]
	var fixed_count = 0
	for image in images:
		if image.has("uri"):
			var old_uri = image["uri"]
			var new_uri = old_uri.uri_decode()
			if old_uri != new_uri:
				image["uri"] = new_uri
				fixed_count += 1
				#print("    Fixed URI: ", old_uri, " -> ", new_uri)

	if fixed_count > 0:
		# Write the updated JSON back
		var updated_json = JSON.stringify(gltf_data, "\t")
		gltf_file = FileAccess.open(gltf_path, FileAccess.WRITE)
		if gltf_file:
			gltf_file.store_string(updated_json)
			gltf_file.close()
			#print("    Fixed ", fixed_count, " URIs in GLTF")
		else:
			printerr("    Failed to write updated GLTF")

func _fix_texture_filenames_post_export(scene_root: Node, gltf_path: String):
	"""Post-process exported GLTF to fix texture filenames"""
	#print("  Post-processing texture filenames...")

	# Collect all unique textures from materials
	var texture_list = []
	_collect_textures_from_scene_ordered(scene_root, texture_list)

	if texture_list.size() == 0:
		#print("    No textures to fix")
		return

	#print("    Found ", texture_list.size(), " textures in scene")

	# Read the GLTF JSON
	var gltf_file = FileAccess.open(gltf_path, FileAccess.READ)
	if not gltf_file:
		printerr("    Failed to open GLTF for post-processing")
		return

	var gltf_json_text = gltf_file.get_as_text()
	gltf_file.close()

	var json = JSON.new()
	if json.parse(gltf_json_text) != OK:
		printerr("    Failed to parse GLTF JSON")
		return

	var gltf_data = json.data
	if not gltf_data is Dictionary or not gltf_data.has("images"):
		#print("    No images in GLTF to fix")
		return

	var images = gltf_data["images"]
	var base_dir = gltf_path.get_base_dir()

	# Fix each image URI and rename the file
	for i in range(images.size()):
		if i >= texture_list.size():
			break

		var image = images[i]
		var old_uri = image.get("uri", "")
		if old_uri.is_empty():
			continue

		# Decode the URI
		var old_uri_decoded = old_uri.uri_decode()
		var old_file_path = base_dir + "/" + old_uri_decoded

		# Get the texture to determine the new name
		var texture = texture_list[i]
		var new_filename = "texture_" + str(i) + ".png"
		if texture and texture.resource_path:
			new_filename = texture.resource_path.get_file().get_basename() + ".png"

		var new_file_path = base_dir + "/textures/" + new_filename
		var new_uri = "textures/" + new_filename

		#print("    Renaming: ", old_file_path, " -> ", new_file_path)

		# Rename the file on disk
		var dir = DirAccess.open(base_dir)
		if dir and FileAccess.file_exists(old_file_path):
			var err = dir.rename(old_file_path, new_file_path)
			if err == OK:
				# Update the JSON
				image["uri"] = new_uri
				#print("      Success!")
			else:
				printerr("      Failed to rename file: ", err)
		else:
			printerr("      Old file doesn't exist: ", old_file_path)

	# Write the updated JSON back
	var updated_json = JSON.stringify(gltf_data, "\t")
	gltf_file = FileAccess.open(gltf_path, FileAccess.WRITE)
	if gltf_file:
		gltf_file.store_string(updated_json)
		gltf_file.close()
		#print("    Updated GLTF JSON with new texture paths")
	else:
		printerr("    Failed to write updated GLTF")

func _collect_textures_from_scene_ordered(node: Node, texture_list: Array):
	"""Recursively collect textures in order from materials in the scene"""
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		var mesh = mesh_instance.mesh
		if mesh:
			for i in range(mesh.get_surface_count()):
				var mat = mesh.surface_get_material(i)
				if mat and mat is StandardMaterial3D:
					var std_mat = mat as StandardMaterial3D
					if std_mat.albedo_texture and not texture_list.has(std_mat.albedo_texture):
						texture_list.append(std_mat.albedo_texture)
					if std_mat.normal_texture and not texture_list.has(std_mat.normal_texture):
						texture_list.append(std_mat.normal_texture)
					if std_mat.metallic_texture and not texture_list.has(std_mat.metallic_texture):
						texture_list.append(std_mat.metallic_texture)
					if std_mat.roughness_texture and not texture_list.has(std_mat.roughness_texture):
						texture_list.append(std_mat.roughness_texture)

	for child in node.get_children():
		_collect_textures_from_scene_ordered(child, texture_list)

func _collect_textures_from_scene(node: Node, texture_set: Dictionary):
	"""Recursively collect all unique textures from materials in the scene"""
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		var mesh = mesh_instance.mesh
		if mesh:
			for i in range(mesh.get_surface_count()):
				var mat = mesh.surface_get_material(i)
				if mat and mat is StandardMaterial3D:
					var std_mat = mat as StandardMaterial3D
					if std_mat.albedo_texture:
						texture_set[std_mat.albedo_texture] = true
					if std_mat.normal_texture:
						texture_set[std_mat.normal_texture] = true
					if std_mat.metallic_texture:
						texture_set[std_mat.metallic_texture] = true
					if std_mat.roughness_texture:
						texture_set[std_mat.roughness_texture] = true

	for child in node.get_children():
		_collect_textures_from_scene(child, texture_set)

func _list_directory_recursive(path: String, indent: String):
	"""Debug helper to list all files in a directory recursively"""
	var dir = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			if dir.current_is_dir():
				#print(indent + "[DIR] " + file_name)
				_list_directory_recursive(path + "/" + file_name, indent + "  ")
			else:
				var file_path = path + "/" + file_name
				var file = FileAccess.open(file_path, FileAccess.READ)
				var size = 0
				if file:
					size = file.get_length()
					file.close()
				#print(indent + "[FILE] " + file_name + " (" + str(size) + " bytes)")
		file_name = dir.get_next()
	dir.list_dir_end()

func _remove_dir_recursive(path: String):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				_remove_dir_recursive(path + "/" + file_name)
			else:
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		dir.remove(path)
