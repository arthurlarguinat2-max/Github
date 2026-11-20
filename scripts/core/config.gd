## Loads JSON data files from res://data. Keeps game tuning out of the code.
extends RefCounted


static func load_json(path: String, fallback: Dictionary = {}) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Data file missing: %s" % path)
		return fallback
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON in %s" % path)
		return fallback
	return parsed


static func game_config() -> Dictionary:
	return load_json("res://data/game_config.json")
