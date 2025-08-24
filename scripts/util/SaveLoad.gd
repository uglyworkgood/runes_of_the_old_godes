extends Node


func save_json(path: String, data: Dictionary) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))


func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f = FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())
