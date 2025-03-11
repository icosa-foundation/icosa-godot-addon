extends Button

@onready var image_rect: TextureRect = %Image
@onready var name_label: Label = %Name
@onready var author_label: Label = %Author
@onready var asset_tags: FlowContainer = %AssetTags


var asset_data: Dictionary

func setup(data: Dictionary, texture: ImageTexture = null) -> void:
	asset_data = data
	
	# Set the name
	name_label.text = data.get("displayName", "Unnamed Asset")
	
	# Set the author
	author_label.text = data.get("authorName", "Unknown Author")
	
	# Set the image if provided
	if texture:
		image_rect.texture = texture
	
	# Configure image display
	image_rect.custom_minimum_size = Vector2(64, 64)
	image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Set the asset types (only once!)
	var format_types = []
	for format in data.get("formats", []):
		var format_type = format.get("formatType", "").to_lower()
		if not format_type in format_types:
			format_types.append(format_type)
			# Create a tag for each unique format
			var tag = AssetTag.new()
			tag.name = format_type  # Set the node name to the format type
			asset_tags.add_child(tag)
			var tag_color = match_format_color(format_type)
			tag.setup(format_type, tag_color)

func _on_pressed() -> void:
	# Find the glTF format and its resources
	var files_to_download = []
	for format in asset_data.get("formats", []):
		var format_type = format.get("formatType", "").to_lower()
		if format_type in ["gltf", "gltf2", "glb"]:
			# Add main gltf file
			if format.has("root") and format.root.has("url"):
				files_to_download.append(format.root)
			# Add all resources (bin files, textures, etc.)
			for resource in format.get("resources", []):
				if resource.has("url"):
					files_to_download.append(resource)
			break
	
	if files_to_download.is_empty():
		print("No glTF/GLB format found for: ", asset_data.get("name"))
		return
	
	# Download each file
	for file_data in files_to_download:
		var downloader = HTTPDownload.new(
			file_data.url,
			file_data.get("relativePath", "")
		)
		add_child(downloader)
		downloader.download_completed.connect(_on_file_downloaded)

func _on_file_downloaded(save_path: String, success: bool) -> void:
	if success:
		print("File downloaded successfully to: ", save_path)
	else:
		print("Failed to download file")

func match_format_color(format_type: String) -> Color:
	match format_type:
		"gltf", "gltf2":
			return Color(0.2, 0.8, 0.2)  # Green
		"glb":
			return Color(0.2, 0.7, 0.2)  # Slightly darker green
		"obj":
			return Color(0.2, 0.2, 0.8)  # Blue
		"fbx":
			return Color(0.8, 0.2, 0.2)  # Red
		"usdz":
			return Color(0.8, 0.4, 0.0)  # Orange
		_:
			return Color.WHITE  # Default color for unknown formats
