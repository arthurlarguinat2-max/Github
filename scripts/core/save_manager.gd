## Versioned JSON save files with forward migrations.
##
## File layout:
##   { "version": <int>, "saved_at_unix": <float>, "game": { ...simulation... } }
##
## RULE: never break an existing save. When the format changes:
##   1. bump SAVE_VERSION,
##   2. add a `_migrate_vN_to_vN+1` function and register it in _migrate().
## Writes are atomic (temp file + rename) and the previous save is kept as .bak.
extends RefCounted

const SAVE_VERSION := 1
const DEFAULT_PATH := "user://savegame.json"

enum LoadStatus { OK, NO_SAVE, CORRUPTED, TOO_NEW }


## Wraps game data into the versioned envelope.
static func build_envelope(game: Dictionary, now_unix: float) -> Dictionary:
	return {"version": SAVE_VERSION, "saved_at_unix": now_unix, "game": game}


static func save_to_file(game: Dictionary, path: String = DEFAULT_PATH) -> Error:
	var envelope := build_envelope(game, Time.get_unix_time_from_system())
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(envelope))  # Compact: big planets have thousands of cells.
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(tmp_path, path)


## Returns { "status": LoadStatus, "envelope": Dictionary }.
## The envelope is already migrated to SAVE_VERSION when status is OK.
static func load_from_file(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": LoadStatus.NO_SAVE, "envelope": {}}
	var text := FileAccess.get_file_as_string(path)
	var result := parse_and_migrate(text)
	if result.status == LoadStatus.CORRUPTED and FileAccess.file_exists(path + ".bak"):
		# Fall back to the previous save rather than losing everything.
		result = parse_and_migrate(FileAccess.get_file_as_string(path + ".bak"))
	return result


## Pure function (no I/O): parses JSON text and migrates it. Unit-tested.
static func parse_and_migrate(text: String) -> Dictionary:
	# JSON.new().parse() reports errors silently (parse_string logs an engine error).
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {"status": LoadStatus.CORRUPTED, "envelope": {}}
	var envelope: Dictionary = json.data
	var version := int(envelope.get("version", 0))
	if version > SAVE_VERSION:
		# Save written by a newer app version: do not touch it.
		return {"status": LoadStatus.TOO_NEW, "envelope": envelope}
	return {"status": LoadStatus.OK, "envelope": _migrate(envelope)}


static func _migrate(envelope: Dictionary) -> Dictionary:
	var data := envelope.duplicate(true)
	var version := int(data.get("version", 0))
	while version < SAVE_VERSION:
		match version:
			0:
				data = _migrate_v0_to_v1(data)
			_:
				push_error("No migration from save version %d" % version)
				break
		version = int(data.get("version", version + 1))
	return data


## v0 = early prototype format: { "ticks": n, "seed": s } at the root.
## Kept as the reference example of how migrations are written.
static func _migrate_v0_to_v1(old: Dictionary) -> Dictionary:
	return {
		"version": 1,
		"saved_at_unix": float(old.get("saved_at_unix", 0.0)),
		"game": {
			"world_seed": int(old.get("seed", 0)),
			"tick": int(old.get("ticks", 0)),
			"speed": 1,
		},
	}
