extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/simulation/simulation.gd")
const Economy := preload("res://scripts/simulation/economy.gd")


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _config() -> Dictionary:
	var config := _json("res://data/game_config.json")
	config["terrains"] = _json("res://data/terrains.json").terrains
	var buildings := _json("res://data/buildings.json")
	config["buildings"] = buildings.buildings
	config["start"] = buildings.start
	config["townhall"] = _json("res://data/townhall.json").levels
	config["professions"] = _json("res://data/professions.json").professions
	config["objectives"] = _json("res://data/objectives.json").objectives
	return config


func _sim(world_seed: int = 7) -> Simulation:
	return Simulation.new(world_seed, _config())


func _spot(sim: Simulation, id: String) -> int:
	for i in sim.planet.cell_count():
		if sim.economy.can_build(i, id) == "":
			return i
	return -1


func _rich(sim: Simulation) -> void:
	for res in ["food", "wood", "stone", "tools", "water"]:
		sim.economy.stocks[res] = 1000.0


func test_village_starts_with_the_town_hall_only() -> void:
	var sim := _sim()
	var eco := sim.economy
	assert_eq(eco.townhall_level, 1)
	assert_eq(sim.planet.buildings[eco.village_center], "townhall")
	assert_eq(eco.housing(), 4)
	assert_eq(eco.trained_total(), 0)
	assert_eq(eco.idle_villagers(), 4)


func test_buildings_are_locked_by_level() -> void:
	var sim := _sim()
	_rich(sim)
	var eco := sim.economy
	assert_eq(eco.building_limit("mill"), 0)
	var land := sim.planet.terrain.find("plains")
	assert_eq(eco.can_build(land, "mill"), Economy.ERR_LOCKED)
	assert_eq(eco.unlock_level("mill"), 3)
	assert_true(eco.building_limit("hut") > 0)


func test_building_limit_per_level() -> void:
	var sim := _sim()
	_rich(sim)
	var eco := sim.economy
	var limit := eco.building_limit("well")
	for i in limit:
		var cell := _spot(sim, "well")
		assert_true(eco.build(cell, "well"), "well %d" % i)
		eco.complete_construction()
	var any := -1
	for i in sim.planet.cell_count():
		if sim.planet.buildings[i] == "" and eco.in_territory(i) and sim.planet.terrain[i] == "plains":
			any = i
			break
	assert_eq(eco.can_build(any, "well"), Economy.ERR_LIMIT)


func test_construction_takes_time_and_builders() -> void:
	var sim := _sim()
	_rich(sim)
	var eco := sim.economy
	var cell := _spot(sim, "hut")
	assert_true(eco.build(cell, "hut"))
	assert_false(eco.is_active(cell))
	assert_eq(eco.housing(), 4, "a site gives no housing")
	assert_eq(eco.free_builders(), 0)
	assert_eq(eco.can_build(_spot_any(sim, "hut"), "hut"), Economy.ERR_BUILDERS)
	sim.run_ticks(int(sim.ticks_per_day * 0.35))
	assert_true(eco.is_active(cell), "hut built after 0.3 day")
	assert_eq(eco.housing(), 8)
	assert_eq(eco.free_builders(), 1)


func _spot_any(sim: Simulation, id: String) -> int:
	for i in sim.planet.cell_count():
		if sim.planet.buildings[i] == "" and sim.economy.in_territory(i) and sim.planet.terrain[i] in sim.economy.defs[id].terrains:
			return i
	return -1


func test_workers_must_be_trained() -> void:
	var sim := _sim()
	_rich(sim)
	var eco := sim.economy
	var cell := _spot(sim, "gatherer")
	eco.build(cell, "gatherer")
	eco.complete_construction()
	eco.update(0.1)
	assert_eq(eco.workers_at(cell), 0, "untrained villagers can't work")
	assert_true(eco.train("gatherer"))
	assert_eq(eco.idle_villagers(), 3)
	sim.run_ticks(int(sim.ticks_per_day * 0.25))
	assert_eq(eco.trained_count("gatherer"), 1)
	eco.update(0.1)
	assert_eq(eco.workers_at(cell), 1)


func test_training_costs_food_and_respects_slots() -> void:
	var sim := _sim()
	var eco := sim.economy
	var food := eco.stock("food")
	assert_eq(eco.can_train("gatherer"), "")
	eco.train("gatherer")
	assert_almost_eq(eco.stock("food"), food - 4.0)
	assert_eq(eco.can_train("gatherer"), Economy.ERR_SLOTS, "1 training at a time at level 1")
	assert_eq(eco.can_train("miller"), Economy.ERR_LOCKED)


func test_no_training_without_idle_villagers() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.trained["gatherer"] = 4
	assert_eq(eco.can_train("woodcutter"), Economy.ERR_NO_VILLAGER)


func test_townhall_upgrade_needs_population_and_time() -> void:
	var sim := _sim()
	_rich(sim)
	var eco := sim.economy
	assert_eq(eco.can_upgrade_townhall(), Economy.ERR_REQUIREMENT)
	eco.population = 6
	assert_eq(eco.can_upgrade_townhall(), "")
	assert_true(eco.upgrade_townhall())
	assert_eq(eco.townhall_level, 1, "works take time")
	assert_eq(eco.can_upgrade_townhall(), Economy.ERR_BUSY)
	var levels := []
	eco.level_up.connect(func(l): levels.append(l))
	eco.update(1.01)
	assert_eq(eco.townhall_level, 2)
	assert_eq(levels, [2])
	assert_true(eco.building_limit("field") > 0, "fields unlocked at level 2")


func test_level_up_grows_territory_and_housing() -> void:
	var sim := _sim()
	_rich(sim)
	var eco := sim.economy
	var area := _territory_size(sim)
	var housing := eco.housing()
	eco.population = 6
	eco.upgrade_townhall()
	eco.update(2.0)
	assert_true(_territory_size(sim) > area, "territory grows")
	assert_true(eco.housing() > housing, "town hall houses more")


func _territory_size(sim: Simulation) -> int:
	var n := 0
	for i in sim.planet.cell_count():
		if sim.economy.in_territory(i):
			n += 1
	return n


func test_perks_boost_production() -> void:
	var sim := _sim()
	_rich(sim)
	var eco := sim.economy
	var cell := _spot(sim, "gatherer")
	eco.build(cell, "gatherer")
	eco.complete_construction()
	eco.trained["gatherer"] = 2
	eco.update(0.5)
	var before := float(eco.building_rate(cell).food)
	eco.townhall_level = 2  # "Cueillette experte": +10 % food
	eco.update(0.5)
	assert_almost_eq(float(eco.building_rate(cell).food), before * 1.1, 0.01)


func test_people_leaving_lose_their_job() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.trained = {"gatherer": 2, "woodcutter": 2}
	eco.stocks["food"] = 0.0
	eco.daily_update()  # Famine: one person dies.
	assert_eq(eco.population, 3)
	assert_eq(eco.trained_total(), 3)


func test_progress_survives_save() -> void:
	var sim := _sim()
	_rich(sim)
	var eco := sim.economy
	var cell := _spot(sim, "hut")
	eco.build(cell, "hut")
	eco.train("gatherer")
	eco.trained["water_carrier"] = 1
	eco.population = 6
	var loaded := _sim(1)
	loaded.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())))
	var e2 := loaded.economy
	assert_false(e2.is_active(cell), "still a construction site")
	assert_almost_eq(e2.construction_progress(cell), eco.construction_progress(cell), 0.01)
	assert_eq(e2.training.size(), 1)
	assert_eq(e2.trained_count("water_carrier"), 1)
	assert_eq(e2.townhall_level, 1)


func test_old_village_becomes_a_town_hall() -> void:
	var sim := _sim()
	var eco := sim.economy
	# Build a save shaped like Phase 3: campfire center, working gatherer, no town hall data.
	sim.planet.buildings[eco.village_center] = "campfire"
	var spot := -1
	for i in sim.planet.cell_count():
		if sim.planet.buildings[i] == "" and sim.planet.terrain[i] == "plains":
			spot = i
			break
	sim.planet.buildings[spot] = "gatherer"
	var data := sim.to_dict()
	for key in ["townhall_level", "townhall_upgrade_left", "trained", "training", "construction"]:
		data.economy.erase(key)
	var loaded := _sim(1)
	loaded.from_dict(JSON.parse_string(JSON.stringify(data)))
	var e2 := loaded.economy
	assert_eq(loaded.planet.buildings[e2.village_center], "townhall")
	assert_eq(e2.townhall_level, 1)
	assert_eq(e2.trained_count("gatherer"), 2, "existing workers are trained")
	e2.update(0.1)
	assert_eq(e2.workers_at(spot), 2)


func test_outposts_expand_territory() -> void:
	var sim := _sim()
	_rich(sim)
	var eco := sim.economy
	eco.townhall_level = 3
	eco._rebuild_caches()
	var area := _territory_size(sim)
	var edge := -1
	for i in sim.planet.cell_count():
		if eco.can_build(i, "outpost") == "":
			var outside := 0
			for nb in sim.planet.grid.neighbors[i]:
				if not eco.in_territory(nb):
					outside += 1
			if outside >= 2:
				edge = i
				break
	assert_true(edge >= 0, "an edge cell for an outpost")
	eco.build(edge, "outpost")
	eco.complete_construction()
	assert_true(_territory_size(sim) > area)


func test_every_level_is_reachable() -> void:
	# Each level's upgrade only costs resources that earlier levels can produce.
	var levels: Array = _json("res://data/townhall.json").levels
	var producers := {"food": ["gatherer", "field", "bakery"], "wood": ["woodcutter"], "stone": ["quarry"], "tools": ["workshop"]}
	for i in range(1, levels.size()):
		var available: Dictionary = levels[i - 1].buildings
		for res in levels[i].get("cost", {}):
			var ok := false
			for b in producers.get(res, []):
				if int(available.get(b, 0)) > 0:
					ok = true
			assert_true(ok, "level %d needs %s but nothing produces it" % [i + 1, res])


func test_professions_have_texts_and_buildings() -> void:
	var fr := _json("res://data/locale/fr.json")
	var professions: Dictionary = _json("res://data/professions.json").professions
	var buildings: Dictionary = _json("res://data/buildings.json").buildings
	for id in professions:
		assert_true(fr.has(professions[id].name_key), id)
	for id in buildings:
		var p := str(buildings[id].get("profession", ""))
		if p != "":
			assert_true(professions.has(p), "%s needs unknown profession %s" % [id, p])
	for level in _json("res://data/townhall.json").levels:
		for perk in level.get("perks", []):
			assert_true(fr.has(perk.name_key), perk.name_key)
