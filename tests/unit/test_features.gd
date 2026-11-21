extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/simulation/simulation.gd")
const Objectives := preload("res://scripts/simulation/objectives.gd")
const Events := preload("res://scripts/simulation/events.gd")
const GameStateScript := preload("res://scripts/core/game_state.gd")


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _config() -> Dictionary:
	var config := _json("res://data/game_config.json")
	config["terrains"] = _json("res://data/terrains.json").terrains
	var buildings := _json("res://data/buildings.json")
	config["buildings"] = buildings.buildings
	config["start"] = buildings.start
	config["customization"] = _json("res://data/customization.json")
	config["objectives"] = _json("res://data/objectives.json").objectives
	config["events"] = _json("res://data/events.json").events
	return config


func _sim(world_seed: int = 3) -> Simulation:
	return Simulation.new(world_seed, _config())


func _goal(sim: Simulation, id: String) -> Dictionary:
	for obj in sim.objective_defs:
		if obj.id == id:
			return obj
	return {}


func test_objective_rewards_are_given_once() -> void:
	var sim := _sim()
	var eco := sim.economy
	var cell := -1
	for i in sim.planet.cell_count():
		if eco.can_build(i, "well") == "":
			cell = i
			break
	assert_true(cell >= 0, "no spot for a well")
	eco.build(cell, "well")
	var wood := eco.stock("wood")
	sim.check_objectives()
	assert_true("first_well" in sim.completed_objectives)
	assert_almost_eq(eco.stock("wood"), wood + 10.0)
	sim.check_objectives()
	assert_almost_eq(eco.stock("wood"), wood + 10.0, 0.001, "not twice")


func test_objective_progress() -> void:
	var sim := _sim()
	sim.economy.population = 7
	var p := Objectives.progress(sim, _goal(sim, "pop_10"))
	assert_eq(p, [7.0, 10.0])


func test_travelers_need_room() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.population = eco.housing() - 1  # Room for one only.
	sim.pending_event = "travelers"
	sim.resolve_event(0)
	assert_eq(eco.population, eco.housing())
	assert_eq(sim.pending_event, "")


func test_event_effects_change_stocks_and_mood() -> void:
	var sim := _sim()
	var eco := sim.economy
	var food := eco.stock("food")
	var happy := eco.happiness
	Events.apply(sim, {"food": -10, "happiness": 15})
	assert_almost_eq(eco.stock("food"), food - 10.0)
	assert_almost_eq(eco.happiness, minf(100.0, happy + 15.0))


func test_events_happen_and_respect_conditions() -> void:
	var sim := _sim()
	sim.economy.population = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 50:
		var id := Events.pick(sim, sim.event_defs, rng)
		var ev := Events.find(sim.event_defs, id)
		assert_true(sim.economy.population >= int(ev.get("min_population", 0)), "%s needs more people" % id)


func test_pending_event_survives_save() -> void:
	var sim := _sim()
	sim.pending_event = "storm"
	sim.completed_objectives = ["first_well"]
	sim.tutorial_step = 4
	var loaded := _sim(1)
	loaded.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())))
	assert_eq(loaded.pending_event, "storm")
	assert_eq(loaded.completed_objectives, ["first_well"])
	assert_eq(loaded.tutorial_step, 4)


func test_hut_upgrades_to_longhouse() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.stocks["wood"] = 110.0
	eco.stocks["stone"] = 100.0
	var hut := -1
	for i in sim.planet.cell_count():
		if eco.can_build(i, "hut") == "":
			hut = i
			break
	assert_true(eco.build(hut, "hut"))
	var housing := eco.housing()
	assert_eq(eco.can_upgrade(hut), "")
	assert_true(eco.upgrade(hut))
	assert_eq(sim.planet.buildings[hut], "longhouse")
	assert_eq(eco.housing(), housing + 5)
	assert_almost_eq(eco.stock("wood"), 80.0)


func test_longhouse_is_not_in_build_menu() -> void:
	var sim := _sim()
	for i in sim.planet.cell_count():
		assert_true(sim.economy.can_build(i, "longhouse") != "")


func test_territory_grows_with_planet_size() -> void:
	var small_cfg := _config()
	small_cfg["planet"]["frequency"] = 8
	var big_cfg := _config()
	big_cfg["planet"]["frequency"] = 16
	var small := Simulation.new(5, small_cfg)
	var big := Simulation.new(5, big_cfg)
	assert_eq(small.economy.territory_scale, 1)
	assert_eq(big.economy.territory_scale, 2)


func test_ocean_option_changes_the_planet() -> void:
	var wet := _config()
	wet["planet"]["ocean_fraction"] = 0.7
	var dry := _config()
	dry["planet"]["ocean_fraction"] = 0.38
	var a := Simulation.new(9, wet).planet
	var b := Simulation.new(9, dry).planet
	var water_a := a.count_terrain("ocean") + a.count_terrain("shallow")
	var water_b := b.count_terrain("ocean") + b.count_terrain("shallow")
	assert_true(water_a > water_b + 200, "%d vs %d" % [water_a, water_b])


func test_seed_text_is_stable() -> void:
	assert_eq(GameStateScript.seed_from_text(""), -1)
	assert_eq(GameStateScript.seed_from_text("1234"), 1234)
	assert_eq(GameStateScript.seed_from_text("Gaïa"), GameStateScript.seed_from_text("gaïa"))
	assert_true(GameStateScript.seed_from_text("Gaïa") >= 0)


func test_tutorial_steps_are_valid() -> void:
	var fr := _json("res://data/locale/fr.json")
	var buildings: Dictionary = _json("res://data/buildings.json").buildings
	var known := ["next", "rotate", "zoom", "select", "needs", "speed", "goals", "village"]
	var professions: Dictionary = _json("res://data/professions.json").professions
	for step in _json("res://data/tutorial.json").steps:
		assert_true(fr.has(step.text_key), step.text_key)
		var condition := str(step.condition)
		if condition.begins_with("building:"):
			assert_true(buildings.has(condition.split(":")[1]), condition)
		elif condition.begins_with("trained:"):
			assert_true(professions.has(condition.split(":")[1]), condition)
		else:
			assert_true(condition in known, condition)


func test_objectives_and_events_have_texts() -> void:
	var fr := _json("res://data/locale/fr.json")
	var en := _json("res://data/locale/en.json")
	for obj in _json("res://data/objectives.json").objectives:
		assert_true(fr.has(obj.title_key) and en.has(obj.title_key), obj.title_key)
	for ev in _json("res://data/events.json").events:
		for key in [ev.title_key, ev.text_key]:
			assert_true(fr.has(key) and en.has(key), key)
		for choice in ev.choices:
			assert_true(fr.has(choice.label_key) and en.has(choice.label_key), choice.label_key)


func test_huge_planet_is_playable() -> void:
	var cfg := _config()
	cfg["planet"]["frequency"] = 20
	var sim := Simulation.new(2, cfg)
	assert_eq(sim.planet.cell_count(), 4002)
	assert_true(sim.economy.village_center >= 0)
	sim.run_ticks(sim.ticks_per_day)
	assert_eq(sim.day(), 2)


func test_tutorial_buildings_are_affordable_at_start() -> void:
	# The tutorial asks for a well, a gatherer and a hut with the starting stocks.
	var sim := _sim()
	var eco := sim.economy
	var total := {}
	for id in ["well", "gatherer", "hut"]:
		var cost: Dictionary = eco.defs[id].cost
		for res in cost:
			total[res] = float(total.get(res, 0.0)) + float(cost[res])
	for res in total:
		assert_true(eco.stock(res) >= total[res], "%s: need %d, have %d" % [res, total[res], eco.stock(res)])
