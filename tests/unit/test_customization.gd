extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/simulation/simulation.gd")


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _config() -> Dictionary:
	var config := _json("res://data/game_config.json")
	config["terrains"] = _json("res://data/terrains.json").terrains
	var buildings := _json("res://data/buildings.json")
	config["buildings"] = buildings.buildings
	config["start"] = buildings.start
	config["customization"] = _json("res://data/customization.json")
	return config


func test_default_planet_has_642_cells() -> void:
	var sim := Simulation.new(3, _config())
	assert_eq(sim.planet.cell_count(), 642)


func test_planet_sizes_build_the_right_grid() -> void:
	for size in _json("res://data/customization.json").planet_sizes:
		var config := _config()
		config["planet"]["frequency"] = int(size.frequency)
		var sim := Simulation.new(5, config)
		var f := int(size.frequency)
		assert_eq(sim.planet.cell_count(), 10 * f * f + 2, str(size.id))
		assert_true(sim.economy.village_center >= 0, "village on %s planet" % size.id)


func test_planet_name_is_deterministic_and_nice() -> void:
	var syllables: Array = _json("res://data/customization.json").name_syllables
	var a := Simulation.generate_name(12, syllables)
	assert_eq(a, Simulation.generate_name(12, syllables))
	assert_true(a.length() >= 4 and a.length() <= 12, a)
	assert_eq(a.substr(0, 1), a.substr(0, 1).to_upper())


func test_customization_survives_save() -> void:
	var sim := Simulation.new(9, _config())
	sim.custom["planet_name"] = "Gaïa"
	sim.custom["palette"] = "mars"
	sim.custom["village_color"] = "3a7bc0"
	var loaded := Simulation.new(1, _config())
	loaded.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())))
	assert_eq(loaded.custom, sim.custom)


func test_old_save_gets_a_generated_name() -> void:
	var sim := Simulation.new(9, _config())
	var data := sim.to_dict()
	data.erase("custom")
	var loaded := Simulation.new(1, _config())
	loaded.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_true(str(loaded.custom.planet_name) != "")
	assert_eq(loaded.custom.palette, "classic")


func test_palettes_only_use_known_terrains() -> void:
	var terrains: Dictionary = _json("res://data/terrains.json").terrains
	var palettes: Dictionary = _json("res://data/customization.json").palettes
	for id in palettes:
		for terrain in palettes[id].colors:
			assert_true(terrains.has(terrain), "palette %s: unknown terrain %s" % [id, terrain])


func test_every_building_has_an_icon_and_texts() -> void:
	var fr := _json("res://data/locale/fr.json")
	var buildings: Dictionary = _json("res://data/buildings.json").buildings
	for id in buildings:
		assert_true(FileAccess.file_exists("res://assets/icons/ui/%s.svg" % id), "icon for " + id)
		for key in ["name_key", "desc_key", "short_key"]:
			assert_true(fr.has(buildings[id][key]), "%s.%s" % [id, key])


func test_every_option_has_a_label() -> void:
	var fr := _json("res://data/locale/fr.json")
	var options := _json("res://data/customization.json")
	for group in ["palettes", "skies"]:
		for id in options[group]:
			assert_true(fr.has(options[group][id].name_key), "%s.%s" % [group, id])
	for size in options.planet_sizes:
		assert_true(fr.has(size.name_key), str(size.id))
