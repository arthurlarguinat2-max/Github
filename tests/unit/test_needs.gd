extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/simulation/simulation.gd")
const Economy := preload("res://scripts/simulation/economy.gd")


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _sim(world_seed: int = 7) -> Simulation:
	var config := _json("res://data/game_config.json")
	config["terrains"] = _json("res://data/terrains.json").terrains
	var buildings := _json("res://data/buildings.json")
	config["buildings"] = buildings.buildings
	config["start"] = buildings.start
	var sim := Simulation.new(world_seed, config)
	sim.economy.stocks["wood"] = 500.0
	sim.economy.stocks["stone"] = 500.0
	sim.economy.population = 30  # Enough workers for every test.
	for p in ["water_carrier", "gatherer", "woodcutter", "stonecutter", "farmer", "miller", "baker", "artisan", "healer"]:
		sim.economy.trained[p] = 3
	return sim


## Places a building on the first free cell that accepts it (ignores territory).
func _place(sim: Simulation, id: String) -> int:
	var eco := sim.economy
	for i in sim.planet.cell_count():
		if sim.planet.buildings[i] == "" and sim.planet.terrain[i] in eco.defs[id].terrains:
			sim.planet.buildings[i] = id
			eco._rebuild_caches()
			return i
	return -1


func test_new_village_has_water() -> void:
	var sim := _sim()
	assert_true(sim.economy.stock("water") > 0.0)


func test_people_drink_water() -> void:
	var sim := _sim()
	var eco := sim.economy
	var water := eco.stock("water")
	eco.update(0.5)
	assert_almost_eq(eco.stock("water"), water - eco.population * 0.5, 0.01)


func test_well_produces_water() -> void:
	var sim := _sim()
	var cell := _place(sim, "well")
	sim.economy.update(1.0)
	assert_true(float(sim.economy.building_rate(cell).get("water", 0.0)) >= 4.0)


func test_well_is_better_near_water() -> void:
	var sim := _sim()
	var eco := sim.economy
	var near := -1
	var far := -1
	for i in sim.planet.cell_count():
		if sim.planet.buildings[i] != "" or not (sim.planet.terrain[i] in eco.defs.well.terrains):
			continue
		if near < 0 and eco.near_water(i):
			near = i
		elif far < 0 and not eco.near_water(i):
			far = i
	sim.planet.buildings[near] = "well"
	sim.planet.buildings[far] = "well"
	eco._rebuild_caches()
	eco.update(1.0)
	assert_almost_eq(float(eco.building_rate(near).water), float(eco.building_rate(far).water) * 1.5, 0.01)


func test_bread_chain_turns_grain_into_food() -> void:
	var sim := _sim()
	var eco := sim.economy
	var mill := _place(sim, "mill")
	var bakery := _place(sim, "bakery")
	eco.stocks["grain"] = 100.0
	eco.update(0.5)
	assert_true(eco.stock("flour") > 0.0 or float(eco.building_rate(bakery).get("food", 0.0)) > 0.0, "flour made")
	assert_true(eco.stock("grain") < 100.0, "grain used")
	eco.update(0.5)
	assert_true(float(eco.building_rate(bakery).get("food", 0.0)) > 10.0, "bread baked: %s" % str(eco.building_rate(bakery)))
	assert_true(float(eco.building_inputs(mill).get("grain", 0.0)) > 0.0)


func test_converter_waits_without_input() -> void:
	var sim := _sim()
	var eco := sim.economy
	var mill := _place(sim, "mill")
	eco.stocks["grain"] = 0.0
	eco.update(1.0)
	assert_true(eco.is_waiting(mill))
	assert_almost_eq(eco.stock("flour"), 0.0)


func test_tools_boost_production() -> void:
	var sim := _sim()
	var eco := sim.economy
	var cell := _place(sim, "gatherer")
	eco.stocks["tools"] = 0.0
	eco.update(1.0)
	var without := float(eco.building_rate(cell).food)
	eco.stocks["tools"] = 10.0
	eco.update(1.0)
	var with_tools := float(eco.building_rate(cell).food)
	assert_almost_eq(with_tools, without * 1.25, 0.01)
	assert_true(eco.stock("tools") < 10.0, "tools wear out")


func test_happiness_sets_productivity() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.happiness = 0.0
	assert_almost_eq(eco.productivity(), 0.6)
	eco.happiness = 100.0
	assert_almost_eq(eco.productivity(), 1.2)


func test_leisure_raises_happiness() -> void:
	var sim := _sim()
	var eco := sim.economy
	var before := Economy.target_of(eco.happiness_factors())
	_place(sim, "stone_circle")
	assert_almost_eq(Economy.target_of(eco.happiness_factors()), before + 10.0, 0.01)


func test_thirst_hurts_health_and_kills() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.population = 4
	eco.stocks["food"] = 100.0
	eco.stocks["water"] = 0.0
	var health := eco.health
	eco.daily_update()
	assert_true(eco.health < health, "health drops without water")
	assert_eq(eco.population, 3)


func test_healer_improves_health() -> void:
	var sim := _sim()
	var eco := sim.economy
	var before := Economy.target_of(eco.health_factors())
	_place(sim, "healer")
	eco.update(0.01)
	assert_true(Economy.target_of(eco.health_factors()) > before)


func test_no_births_when_unhappy() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.population = 2
	eco.stocks["food"] = 100.0
	eco.stocks["water"] = 100.0
	eco.happiness = 25.0
	eco.daily_update()
	assert_true(eco.population <= 2)


func test_wellbeing_survives_save() -> void:
	var sim := _sim()
	sim.economy.happiness = 73.5
	sim.economy.health = 41.25
	sim.economy.stocks["flour"] = 12.0
	var loaded := Simulation.new(1, {"terrains": sim.terrain_defs, "buildings": sim.building_defs, "start": sim.start_settings, "economy": sim.economy_settings, "planet": sim.planet_settings})
	loaded.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())))
	assert_almost_eq(loaded.economy.happiness, 73.5, 0.01)
	assert_almost_eq(loaded.economy.health, 41.25, 0.01)
	assert_almost_eq(loaded.economy.stock("flour"), 12.0, 0.01)


func test_phase2_save_gets_water() -> void:
	var sim := _sim()
	var data := sim.to_dict()
	data.economy.stocks.erase("water")
	data.economy.erase("happiness")
	var loaded := Simulation.new(1, {"terrains": sim.terrain_defs, "buildings": sim.building_defs, "start": sim.start_settings, "economy": sim.economy_settings, "planet": sim.planet_settings})
	loaded.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_almost_eq(loaded.economy.stock("water"), 40.0)
	assert_true(loaded.economy.happiness > 0.0)


func test_every_building_has_a_known_category() -> void:
	var file := _json("res://data/buildings.json")
	var ids := []
	for cat in file.categories:
		ids.append(cat.id)
	for id in file.buildings:
		assert_true(file.buildings[id].get("category", "") in ids, "category of " + id)
