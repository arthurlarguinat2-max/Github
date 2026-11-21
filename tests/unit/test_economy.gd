extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/simulation/simulation.gd")
const Economy := preload("res://scripts/simulation/economy.gd")


func _config() -> Dictionary:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_config.json"))
	config["terrains"] = JSON.parse_string(FileAccess.get_file_as_string("res://data/terrains.json")).terrains
	var buildings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/buildings.json"))
	config["buildings"] = buildings.buildings
	config["start"] = buildings.start
	return config


func _sim(world_seed: int = 7) -> Simulation:
	return Simulation.new(world_seed, _config())


## First free cell in the territory where `id` can go if we ignore the cost.
func _spot(sim: Simulation, id: String) -> int:
	var eco := sim.economy
	for i in sim.planet.cell_count():
		var reason := eco.can_build(i, id)
		if reason == "" or reason == Economy.ERR_COST:
			return i
	return -1


func test_new_game_founds_a_village() -> void:
	for s in [1, 2, 3, 7, 42]:
		var sim := _sim(s)
		var eco := sim.economy
		assert_true(eco.village_center >= 0, "seed %d has no village" % s)
		assert_eq(sim.planet.buildings[eco.village_center], "campfire")
		assert_eq(eco.building_cells().size(), 2, "campfire + hut for seed %d" % s)
		assert_eq(eco.population, 4)
		assert_eq(eco.housing(), 4)


func test_build_costs_resources() -> void:
	var sim := _sim()
	var eco := sim.economy
	var cell := _spot(sim, "hut")
	assert_true(cell >= 0, "no spot for a hut")
	var wood_before := eco.stock("wood")
	assert_true(eco.build(cell, "hut"))
	assert_almost_eq(eco.stock("wood"), wood_before - 10.0)
	assert_eq(eco.housing(), 8)
	assert_false(eco.build(cell, "hut"), "cell already occupied")


func test_cannot_build_without_resources() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.stocks["wood"] = 3.0
	var cell := _spot(sim, "hut")
	assert_eq(eco.can_build(cell, "hut"), Economy.ERR_COST)
	assert_false(eco.build(cell, "hut"))


func test_cannot_build_outside_territory() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.stocks["wood"] = 999.0
	var far := -1
	for i in sim.planet.cell_count():
		if not eco.in_territory(i) and sim.planet.terrain[i] == "plains":
			far = i
			break
	assert_true(far >= 0)
	assert_eq(eco.can_build(far, "hut"), Economy.ERR_TERRITORY)


func test_cannot_build_on_water() -> void:
	var sim := _sim()
	var ocean := sim.planet.terrain.find("ocean")
	assert_eq(sim.economy.can_build(ocean, "hut"), Economy.ERR_TERRAIN)


func test_people_eat_food() -> void:
	var sim := _sim()
	var eco := sim.economy
	var food := eco.stock("food")
	sim.run_ticks(sim.ticks_per_day / 2)  # Half a day, no producer yet.
	assert_almost_eq(eco.stock("food"), food - eco.population * 0.5, 0.05)


func test_gatherer_produces_food() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.stocks["wood"] = 100.0
	var cell := _spot(sim, "gatherer")
	assert_true(eco.build(cell, "gatherer"))
	eco.update(1.0)
	var rate: Dictionary = eco.building_rate(cell)
	assert_true(float(rate.get("food", 0.0)) > 2.0, "gatherer output %s" % str(rate))
	assert_eq(eco.workers_at(cell), 2)


func test_famine_kills_and_growth_fills_huts() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.stocks["food"] = 0.0
	eco.daily_update()
	assert_eq(eco.population, 3, "famine")
	eco.stocks["food"] = 100.0
	eco.daily_update()
	assert_eq(eco.population, 4, "birth up to housing")
	eco.daily_update()
	assert_eq(eco.population, 4, "no birth without housing")


func test_extraction_depletes_deposits() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.stocks["wood"] = 100.0
	var cell := _spot(sim, "woodcutter")
	assert_true(eco.build(cell, "woodcutter"))
	var total_before := _wood_around(sim, cell)
	eco.update(2.0)
	var gained: float = eco.building_rate(cell).get("wood", 0.0) * 2.0
	assert_almost_eq(_wood_around(sim, cell), total_before - gained, 0.05)


func _wood_around(sim: Simulation, cell: int) -> float:
	var total := float(sim.planet.resources[cell].get("wood", 0.0))
	for nb in sim.planet.grid.neighbors[cell]:
		total += float(sim.planet.resources[nb].get("wood", 0.0))
	return total


func test_demolish_refunds_half() -> void:
	var sim := _sim()
	var eco := sim.economy
	var cell := _spot(sim, "hut")
	eco.build(cell, "hut")
	var wood := eco.stock("wood")
	assert_true(eco.demolish(cell))
	assert_almost_eq(eco.stock("wood"), wood + 5.0)
	assert_false(eco.demolish(eco.village_center), "village center stays")


func test_economy_survives_save() -> void:
	var sim := _sim(11)
	var eco := sim.economy
	var cell := _spot(sim, "hut")
	eco.build(cell, "hut")
	sim.run_ticks(sim.ticks_per_day * 3)
	var json := JSON.stringify(sim.to_dict())
	var loaded := Simulation.new(1, _config())
	loaded.from_dict(JSON.parse_string(json))
	assert_eq(loaded.planet.buildings, sim.planet.buildings)
	assert_eq(loaded.economy.population, eco.population)
	assert_almost_eq(loaded.economy.stock("food"), eco.stock("food"), 0.02)
	assert_eq(loaded.economy.village_center, eco.village_center)
	assert_eq(loaded.economy.housing(), eco.housing())


func test_phase1_save_gets_a_village() -> void:
	var sim := _sim(5)
	var old := sim.to_dict()
	old.erase("economy")
	old["planet"].erase("buildings")
	var loaded := Simulation.new(1, _config())
	loaded.from_dict(JSON.parse_string(JSON.stringify(old)))
	assert_true(loaded.economy.village_center >= 0)
	assert_eq(loaded.economy.population, 4)


func test_offline_progress_runs_the_economy() -> void:
	var sim := _sim()
	var food := sim.economy.stock("food")
	sim.advance_offline(3600.0, 10.0, 8 * 3600.0, 0.5)  # 18000 ticks = 30 days
	assert_true(sim.economy.stock("food") < food, "people ate while away")
