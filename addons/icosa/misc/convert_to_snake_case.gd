@tool
## TODO: Remove this if not used.
## this was made so that brush materials fit into the godot project standards, like snake_case filenames
## but because brush materials are from Unity / C# so the namespace is already decided and it makes it much easier to work with.


extends EditorScript

var path = "res://godot_brush_materials/"

func _run() -> void:
	recurse(path)
	print("Renaming complete!")


func recurse(current_path: String) -> void:
	var dir = DirAccess.open(current_path)
	if dir == null:
		print("Failed to open directory: ", current_path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = current_path + "/" + file_name  # Concatenate paths manually
		
		if dir.current_is_dir():
			# Recursively handle directories first
			recurse(full_path)

			# Rename the directory
			var new_dir_name = file_name.to_snake_case()
			if new_dir_name != file_name:
				var new_full_path = current_path + "/" + new_dir_name
				if dir.rename(full_path, new_full_path) != OK:
					print("Failed to rename directory: ", full_path)
		else:
			# Rename files
			var new_file_name = file_name.to_snake_case()
			if new_file_name != file_name:
				var new_full_path = current_path + "/" + new_file_name
				if dir.rename(full_path, new_full_path) != OK:
					print("Failed to rename file: ", full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
