extends "res://tests/test_case.gd"

const PlanetState := preload("res://scripts/simulation/planet_state.gd")
const Simulation := preload("res://scripts/simulation/simulation.gd")


func _terrains() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/terrains.json")).terrains


func _settings() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/game_config.json")).planet


func _planet(world_seed: int) -> PlanetState:
	var p := PlanetState.new(int(_settings().frequency))
	p.generate(world_seed, _terrains(), _settings())
	return p


func test_same_seed_same_planet() -> void:
	var a := _planet(1234)
	var b := _planet(1234)
	assert_eq(a.terrain, b.terrain)
	assert_eq(a.fertility, b.fertility)
	assert_eq(a.resources, b.resources)


func test_different_seeds_differ() -> void:
	assert_true(_planet(1).terrain != _planet(2).terrain)


func test_every_terrain_is_defined() -> void:
	var defs := _terrains()
	var p := _planet(77)
	for t in p.terrain:
		assert_true(defs.has(t), "unknown terrain " + t)


func test_ocean_share_is_reasonable() -> void:
	for s in [1, 2, 3, 4, 5]:
		var p := _planet(s)
		var water := p.count_terrain("ocean") + p.count_terrain("shallow")
		var share := float(water) / p.cell_count()
		assert_true(share > 0.35 and share < 0.65, "seed %d water share %f" % [s, share])


func test_varied_land() -> void:
	# Every planet should offer the basics of the stone age.
	for s in [10, 20, 30]:
		var p := _planet(s)
		assert_true(p.count_terrain("plains") > 0, "seed %d has no plains" % s)
		assert_true(p.count_terrain("forest") + p.count_terrain("hills") + p.count_terrain("mountain") > 0)


func test_poles_are_icy() -> void:
	var p := _planet(5)
	var pole := p.grid.find_cell(Vector3.UP)
	assert_eq(p.terrain[pole], "ice")


func test_forests_have_wood() -> void:
	var p := _planet(9)
	for i in p.cell_count():
		if p.terrain[i] == "forest":
			assert_true(p.resources[i].has("wood"), "forest %d without wood" % i)


func test_planet_survives_save_roundtrip() -> void:
	var config := {"terrains": _terrains(), "planet": _settings()}
	var a := Simulation.new(4242, config)
	a.planet.resources[3]["wood"] = 1  # A change that regeneration would not reproduce.
	var json := JSON.stringify(a.to_dict())
	var b := Simulation.new(1, config)
	b.from_dict(JSON.parse_string(json))
	assert_eq(b.planet.terrain, a.planet.terrain)
	assert_eq(int(b.planet.resources[3]["wood"]), 1)


func test_old_save_without_planet_is_generated() -> void:
	var config := {"terrains": _terrains(), "planet": _settings()}
	var sim := Simulation.new(1, config)
	sim.from_dict({"world_seed": 99, "tick": 5})
	var f := int(_settings().frequency)
	assert_eq(sim.planet.cell_count(), 10 * f * f + 2)
	assert_eq(sim.planet.terrain, _planet(99).terrain)
