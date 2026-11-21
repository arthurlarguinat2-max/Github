## Autoload "UserSettings": device preferences (not tied to a planet).
## Stored in user://settings.json, separate from the game save.
extends Node

signal changed(key: String)

const PATH := "user://settings.json"
const Haptics := preload("res://scripts/platform/haptics.gd")
const DEFAULTS := {
	"haptics": true,
	"language": "",     # "" = follow the device language
	"clouds": true,
	"sky": "soft",
	"last_version": "",  # Used to greet the player after an update.
}

var values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	if FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			for key in parsed:
				if DEFAULTS.has(key) and typeof(parsed[key]) == typeof(DEFAULTS[key]):
					values[key] = parsed[key]
	# Skies from older versions no longer exist: fall back to the default.
	if not (str(values.sky) in ["soft", "sunset", "stars", "aurora", "mist"]):
		values.sky = DEFAULTS.sky
	_apply()


func get_value(key: String):
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, value) -> void:
	values[key] = value
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(values, "\t"))
	_apply()
	changed.emit(key)


func _apply() -> void:
	Haptics.enabled = bool(values.haptics)
	var language := str(values.language)
	if language != "" and language in Loc.available_locales:
		Loc.set_locale(language)
