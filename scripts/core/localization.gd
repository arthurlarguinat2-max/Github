## Autoload "Loc": loads UI strings from res://data/locale/<lang>.json.
##
## JSON keeps texts editable without the Godot editor. French is the default;
## the device language is used when a translation exists for it.
extends Node

const LOCALE_DIR := "res://data/locale/"
const DEFAULT_LOCALE := "fr"

var available_locales: PackedStringArray = []


func _ready() -> void:
	_load_all()
	var device := OS.get_locale_language()
	set_locale(device if device in available_locales else DEFAULT_LOCALE)


func set_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)


func _load_all() -> void:
	var dir := DirAccess.open(LOCALE_DIR)
	if dir == null:
		push_error("Locale folder missing")
		return
	for file_name in dir.get_files():
		# Exported builds may list remapped names; keep only the .json sources.
		if not file_name.ends_with(".json"):
			continue
		var locale := file_name.get_basename()
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(LOCALE_DIR + file_name))
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("Invalid locale file: %s" % file_name)
			continue
		var translation := Translation.new()
		translation.locale = locale
		for key in parsed:
			translation.add_message(key, str(parsed[key]))
		TranslationServer.add_translation(translation)
		available_locales.append(locale)
