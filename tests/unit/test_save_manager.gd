extends "res://tests/test_case.gd"

const SaveManager := preload("res://scripts/core/save_manager.gd")


func test_current_version_loads_unchanged() -> void:
	var env := SaveManager.build_envelope({"tick": 10, "world_seed": 3}, 1000.0)
	var result := SaveManager.parse_and_migrate(JSON.stringify(env))
	assert_eq(result.status, SaveManager.LoadStatus.OK)
	assert_eq(int(result.envelope.version), SaveManager.SAVE_VERSION)
	assert_eq(int(result.envelope.game.tick), 10)


func test_migrates_v0_prototype_save() -> void:
	var result := SaveManager.parse_and_migrate('{"ticks": 500, "seed": 9}')
	assert_eq(result.status, SaveManager.LoadStatus.OK)
	assert_eq(int(result.envelope.version), SaveManager.SAVE_VERSION)
	assert_eq(int(result.envelope.game.tick), 500)
	assert_eq(int(result.envelope.game.world_seed), 9)


func test_corrupted_save_is_detected() -> void:
	var result := SaveManager.parse_and_migrate("{not json")
	assert_eq(result.status, SaveManager.LoadStatus.CORRUPTED)


func test_newer_save_is_not_migrated() -> void:
	var result := SaveManager.parse_and_migrate('{"version": 999, "game": {}}')
	assert_eq(result.status, SaveManager.LoadStatus.TOO_NEW)


func test_file_roundtrip() -> void:
	var path := "user://test_save.json"
	assert_eq(SaveManager.save_to_file({"tick": 42}, path), OK)
	var result := SaveManager.load_from_file(path)
	assert_eq(result.status, SaveManager.LoadStatus.OK)
	assert_eq(int(result.envelope.game.tick), 42)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".bak")


func test_game_data_files_are_valid_json() -> void:
	for path in ["res://data/game_config.json", "res://data/locale/fr.json", "res://data/locale/en.json"]:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_eq(typeof(parsed), TYPE_DICTIONARY, path)


func test_locales_have_same_keys() -> void:
	var fr: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/locale/fr.json"))
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/locale/en.json"))
	for key in fr:
		assert_true(en.has(key), "EN missing key " + key)
	for key in en:
		assert_true(fr.has(key), "FR missing key " + key)
