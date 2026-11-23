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
	var buildings: Dictionary = _json("res://data/buildings.json").buildings
	for i in range(1, levels.size()):
		var previous: Dictionary = levels[i - 1]
		# Resolve supply chains from raw producers, including workshop setup costs.
		var obtainable := {}
		for pass_index in buildings.size():
			var count := obtainable.size()
			for id in previous.buildings:
				var def: Dictionary = buildings[id]
				if not def.get("profession", "") in previous.professions and def.has("profession"):
					continue
				if not def.cost.keys().all(func(r): return obtainable.has(r) or r in ["wood","stone"]):
					continue
				for recipe in def.get("recipes", {"default": def}).values():
					if recipe.get("consumes", {}).keys().all(func(r): return obtainable.has(r)):
						for output in recipe.get("produces", {}):
							obtainable[output] = true
			if obtainable.size() == count:
				break
		for res in levels[i].cost:
			assert_true(obtainable.has(res), "unreachable %s at level %d" % [res, i + 1])



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


func test_orchard_hives_and_baths_survive_reload() -> void:
	var sim := _sim()
	var eco := sim.economy
	_rich(sim)
	assert_eq(eco.unlock_level("orchard"), 1)
	assert_eq(eco.unlock_level("apiary"), 2)
	assert_eq(eco.unlock_level("bathhouse"), 2)
	eco.townhall_level = 2
	eco._rebuild_caches()
	var placed := {}
	for id in ["orchard", "apiary", "bathhouse"]:
		var cell := _spot(sim, id)
		assert_true(cell >= 0, str(id))
		if cell < 0:
			return
		assert_true(eco.build(cell, id))
		eco.complete_construction()
		placed[id] = cell
	var restored := _sim()
	restored.from_dict(sim.to_dict())
	for id in placed:
		assert_eq(restored.planet.buildings[placed[id]], id)
		assert_true(restored.economy.is_active(placed[id]))


func test_food_priority_forecast_matches_work_and_does_not_spend() -> void:
	var sim := _sim()
	var eco := sim.economy
	_rich(sim)
	var gatherer := _spot(sim, "gatherer")
	eco.build(gatherer, "gatherer")
	eco.complete_construction()
	var orchard := _spot(sim, "orchard")
	eco.build(orchard, "orchard")
	eco.complete_construction()
	var dt := 1.0 / sim.ticks_per_day
	var vacant := eco.forecast(orchard, dt)
	assert_almost_eq(vacant.staffing[orchard], 0)
	eco.trained.gatherer = 1
	var before := eco.forecast(-1,dt)
	var stocks_before := eco.stocks.duplicate()
	var deposits_before := sim.planet.resources.duplicate(true)
	var after := eco.forecast(orchard,dt)
	assert_eq(eco.stocks,stocks_before)
	assert_eq(sim.planet.resources,deposits_before)
	assert_true(before.outputs.has(gatherer))
	assert_false(after.outputs.has(gatherer))
	assert_true(after.outputs[orchard].food > 0)
	eco.preferred_cell = orchard
	eco.update(dt)
	assert_eq(eco.workers_at(orchard),1)
	assert_eq(eco.workers_at(gatherer),0)
	assert_almost_eq(eco.rates.food,after.net.food)
	assert_almost_eq(eco.stock("food") - float(stocks_before.food),after.net.food * dt)
	var loaded := _sim()
	loaded.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())))
	assert_eq(loaded.economy.preferred_cell,orchard)
	loaded.economy.preferred_cell = -1
	loaded.economy.update(dt)
	assert_eq(loaded.economy.workers_at(gatherer),1)


func test_empty_stock_reports_unserved_needs_and_real_inputs() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.stocks.food = 0.0
	var flow := eco.forecast(-1,0.01)
	assert_almost_eq(flow.net.food,0)
	assert_almost_eq(flow.households.food,0)
	assert_true(flow.unmet.food > 0)
	_rich(sim)
	eco.townhall_level = 3
	var mill := _spot(sim,"mill")
	eco.build(mill,"mill")
	eco.complete_construction()
	assert_false(eco.forecast(-1,0.01).waiting.has(mill))
	eco.trained.miller = 1
	assert_eq(eco.forecast(-1,0.01).waiting[mill],"grain")
	eco.stocks.grain = 4
	assert_false(eco.forecast(-1,0.01).waiting.has(mill))


func test_plans_reorder_cancel_reload_and_offline_cost_once() -> void:
	var sim := _sim()
	_rich(sim)
	var eco := sim.economy
	var first := _spot(sim,"hut")
	var second := _spot(sim,"well")
	if second == first:
		for cell in sim.planet.cell_count():
			if cell != first and eco.can_build(cell,"well") == "":
				second = cell
				break
	eco.stocks.wood = 0.0
	assert_true(eco.enqueue(first,"hut"))
	assert_false(eco.enqueue(first,"well"))
	assert_true(eco.enqueue(second,"well"))
	assert_false(eco.enqueue(eco.village_center,"well"))
	eco.plans.reverse()
	eco.plans.remove_at(0)
	assert_eq(eco.stock("wood"),0.0)
	eco.update(0.01)
	assert_eq(eco.plans.size(),1)
	eco.stocks.wood = 30.0
	var loaded := _sim()
	loaded.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())))
	loaded.advance_offline(4,10,10,1)
	assert_eq(loaded.planet.buildings[first],"hut")
	assert_eq(loaded.planet.buildings[second],"")
	assert_true(loaded.economy.plans.is_empty())
	assert_almost_eq(loaded.economy.stock("wood"),30.0 - float(eco.defs.hut.cost.wood))
	var saved_wood := loaded.economy.stock("wood")
	var again := _sim()
	again.from_dict(JSON.parse_string(JSON.stringify(loaded.to_dict())))
	again.advance_offline(4,10,10,1)
	assert_almost_eq(again.economy.stock("wood"),saved_wood)


func test_legacy_management_defaults_and_recheck_location() -> void:
	var sim := _sim()
	var old := sim.to_dict()
	old.economy.erase("plans")
	old.economy.erase("preferred_cell")
	var loaded := _sim()
	loaded.from_dict(JSON.parse_string(JSON.stringify(old)))
	assert_eq(loaded.economy.preferred_cell,-1)
	assert_true(loaded.economy.plans.is_empty())
	_rich(loaded)
	var spot := _spot(loaded,"hut")
	assert_true(loaded.economy.enqueue(spot,"hut"))
	assert_true(loaded.economy.build(spot,"well"))
	var wood := loaded.economy.stock("wood")
	loaded.economy.update(0.01)
	assert_eq(loaded.planet.buildings[spot],"well")
	assert_eq(loaded.economy.plans.size(),1)
	assert_almost_eq(loaded.economy.stock("wood"),wood)


func test_kiln_recipe_inputs_staff_and_save() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.townhall_level = 3
	_rich(sim)
	eco.stocks.clay = 20
	var cell := _spot(sim, "kiln")
	assert_true(eco.build(cell, "kiln"))
	assert_false(eco.select_recipe(cell, "pots"))
	eco.complete_construction()
	assert_false(eco.select_recipe(cell, "books"))
	assert_true(eco.select_recipe(cell, "pots"))
	assert_eq(eco.forecast(-1, 0.01).net.pots, 0.0)
	eco.trained.potter = 1
	eco._compute_staffing()
	var flow := eco.forecast(-1, 0.01)
	assert_true(flow.net.pots > 0)
	assert_eq(flow.net.bricks, 0.0)
	assert_true(flow.net.clay < 0)
	var loaded := _sim()
	loaded.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())))
	assert_true(loaded.economy.def_of(cell).produces.has("pots"))
	loaded.economy.stocks.clay = 0.0
	assert_eq(loaded.economy.forecast(-1, 0.01).net.pots, 0.0)
	assert_true(loaded.economy.select_recipe(cell, "bricks"))
	assert_true(loaded.economy.def_of(cell).produces.has("bricks"))
	assert_true(eco.demolish(cell))
	assert_false(eco.recipe_choices.has(cell))


func test_book_chain_supplies_library_and_level_ten() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.townhall_level = 9
	eco.population = 66
	eco._rebuild_caches()
	for res in eco.BASE_RESOURCES:
		eco.stocks[res] = 500
	for id in ["flaxfield", "weavery", "papermill", "bindery"]:
		var cell := _spot(sim, id)
		assert_true(cell >= 0, id)
		assert_true(eco.build(cell, id))
		eco.complete_construction()
		eco.trained[eco.defs[id].profession] = 1
	for res in ["flax", "paper", "linen", "books"]:
		eco.stocks[res] = 0.0
	eco.update(1.0)
	assert_true(eco.stock("books") > 0)
	assert_false(eco.can_upgrade_townhall() == "")
	# Isolate the supply chain from household water demand in this village.
	eco.stocks.water = 10000
	for day in 85:
		eco.update(1.0)
		if eco.can_upgrade_townhall() == "":
			break
	assert_true(eco.upgrade_townhall(), str(eco.stocks))
	eco.update(10.0)
	assert_eq(eco.townhall_level, 10)
	assert_true(eco.build(_spot(sim, "library"), "library"))
	eco.complete_construction()
	assert_eq(eco.building_count("library"), 1)


func test_bronze_study_and_first_ingot_survive_reload() -> void:
	var sim := _sim()
	var eco := sim.economy
	var legacy := sim.to_dict()
	for key in ["bronze_study", "first_ingot", "bronze_equipment"]:
		legacy.economy.erase(key)
	sim.from_dict(JSON.parse_string(JSON.stringify(legacy)))
	eco = sim.economy
	assert_eq(eco.bronze_study, -1.0)
	assert_false(eco.start_bronze_study())
	eco.townhall_level = 10
	eco.population = 20
	eco._rebuild_caches()
	for res in eco.BASE_RESOURCES:
		eco.stocks[res] = 100
	eco.stocks.bronze = 0.0
	eco.stocks.food = 500.0
	eco.stocks.water = 500.0
	assert_eq(eco.building_limit("metal_mine"), 0)
	assert_false(eco.is_profession_unlocked("founder"))
	var library := _spot(sim,"library")
	assert_true(eco.build(library,"library"))
	eco.complete_construction()
	assert_eq(eco.study_blocker(), "ANT_SCHOLAR")
	assert_true(eco.train("scholar"))
	eco.update(1.0)
	eco.stocks.books = 12.0
	assert_true(eco.start_bronze_study())
	assert_eq(eco.stock("books"), 0.0)
	assert_false(eco.start_bronze_study())
	eco.update(0.5)
	var loaded := _sim()
	loaded.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())))
	eco = loaded.economy
	assert_eq(eco.bronze_study, 1.5)
	eco.update(1.5)
	assert_true(eco.building_limit("metal_mine") > 0)
	assert_true(eco.is_profession_unlocked("founder"))
	var mine := _spot(loaded, "metal_mine")
	assert_true(eco.build(mine, "metal_mine"))
	eco.complete_construction()
	var foundry := _spot(loaded, "foundry")
	assert_true(eco.build(foundry, "foundry"))
	eco.complete_construction()
	eco.stocks.tin = 0.0
	eco.stocks.copper = 0.0
	eco.trained.miner = 1
	eco.trained.founder = 1
	eco.update(1.0)
	assert_true(eco.stock("copper") > 0)
	assert_eq(eco.first_ingot, 0.0)
	assert_true(eco.select_recipe(mine, "tin"))
	eco.update(0.1)
	assert_true(eco.first_ingot > 0 and eco.first_ingot < 1)
	assert_false(eco.equip_bronze("field"))
	var partial := eco.first_ingot
	loaded.from_dict(JSON.parse_string(JSON.stringify(loaded.to_dict())))
	eco = loaded.economy
	assert_true(is_equal_approx(eco.first_ingot, partial))
	loaded.advance_offline(60, 10, 3600, 1.0)
	assert_eq(eco.first_ingot, 1.0)
	var field := _spot(loaded, "field")
	assert_true(eco.build(field, "field"))
	eco.complete_construction()
	eco.trained.farmer = 2
	var before: float = eco.forecast(-1, 0.01).outputs[field].grain
	var stock_before := eco.stock("bronze")
	assert_true(eco.equip_bronze("field"))
	assert_false(eco.equip_bronze("field"))
	assert_eq(eco.stock("bronze"), stock_before - 1.0)
	assert_true(is_equal_approx(eco.forecast(-1,0.01).outputs[field].grain, before*1.25))
	sim.from_dict(JSON.parse_string(JSON.stringify(loaded.to_dict())))
	assert_eq(sim.economy.first_ingot, 1.0)
	assert_true(sim.economy.bronze_equipment.has("field"))


func test_market_guards_reserves_and_trades_once_per_visit() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.townhall_level = 10
	eco._rebuild_caches()
	assert_eq(eco.building_limit("market"), 0)
	assert_false(eco.is_profession_unlocked("merchant"))
	eco.first_ingot = 1.0
	eco.bronze_study = 0.0
	for res in eco.BASE_RESOURCES:
		eco.stocks[res] = 100
	var cell := _spot(sim, "market")
	assert_true(eco.build(cell, "market"))
	assert_false(eco.caravan_present())
	eco.complete_construction()
	assert_eq(eco.trade_blocker(0), "TRADE_NEED")
	assert_true(eco.train("merchant"))
	eco.update(1.0)
	eco.trade_reserves.pots = 10
	eco.stocks.pots = 17
	assert_false(eco.trade(0))
	eco.trade_auto.pots = true
	eco.stocks.pots = 18
	eco.plans.append({"id":"cistern","cell":cell})
	assert_eq(eco.planned_material("pots"), 6)
	assert_false(eco.trade(0, true))
	eco.plans.clear()
	var tin_before := eco.stock("tin")
	eco.update(0.01)
	assert_eq(eco.stock("pots"), 10.0)
	assert_eq(eco.stock("tin"), tin_before + 4)
	assert_false(eco.trade(0))
	var loaded := _sim()
	loaded.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())))
	eco = loaded.economy
	assert_eq(eco.last_trade, 0)
	assert_eq(int(eco.trade_reserves.pots), 10)
	assert_true(eco.trade_auto.pots)
	assert_false(eco.trade(0))
	eco.trade_auto.linen = true
	eco.stocks.water = 1000
	eco.stocks.food = 1000
	var linen_before := eco.stock("linen")
	# Isolate the trade from unrelated one-time stock rewards.
	loaded.objective_defs = []
	loaded.advance_offline(200,10,3600,1.0)
	assert_eq(eco.last_trade, 1)
	assert_eq(eco.stock("linen"), linen_before - 6)
	assert_false(eco.trade(0))
	assert_true(eco.demolish(cell))
	assert_false(eco.caravan_present())


func test_seasons_crops_and_mid_sowing_resume() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.townhall_level = 2
	_rich(sim)
	var field := _spot(sim, "field")
	assert_true(eco.build(field,"field"))
	eco.complete_construction()
	eco.trained.farmer = 2
	eco.stocks.tools = 0
	var wheat := eco.forecast(-1,0.01).outputs[field].grain as float
	assert_true(wheat > 0)
	assert_true(is_equal_approx(eco.forecast(-1,0.01,3).outputs[field].grain, 0.45*wheat))
	assert_true(eco.select_recipe(field,"greens"))
	eco.trained.farmer = 0
	eco.update(0.25)
	assert_eq(eco.sowing[field],0.5)
	eco.trained.farmer = 2
	eco.update(0.25)
	var preview := eco.forecast(-1,0.01)
	assert_false(preview.outputs.has(field))
	assert_eq(eco.sowing[field],0.25)
	sim.tick = 6*sim.ticks_per_day-1
	var loaded := _sim()
	loaded.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())))
	eco = loaded.economy
	assert_eq(eco.season_index(),0)
	assert_eq(eco.sowing[field],0.25)
	loaded.advance_offline(20,10,3600,1)
	assert_eq(eco.season_index(),1)
	assert_false(eco.sowing.has(field))
	assert_true(eco.building_rate(field).get("food",0)>0)
	assert_eq(eco.stock("grain"),0.0)
	var winter_greens: float = eco.forecast(-1,0.01,3).outputs[field].food
	assert_true(eco.select_recipe(field,"roots"))
	eco.update(0.5)
	assert_true(eco.forecast(-1,0.01,3).outputs[field].food > winter_greens)
	eco.elapsed_days = 23
	eco.daily_update()
	assert_eq(eco.season_index(),0)


func test_antiquity_chapters_unlock_iron_and_forum() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.townhall_level = 10
	assert_eq(eco.antiquity_chapter(),0)
	assert_false(eco.enter_chapter(2))
	eco.first_ingot = 1
	eco.bronze_study = 0
	for res in eco.BASE_RESOURCES:
		eco.stocks[res] = 100
	var mine := _spot(sim,"metal_mine")
	assert_true(eco.build(mine,"metal_mine"))
	eco.complete_construction()
	var foundry := _spot(sim,"foundry")
	assert_true(eco.build(foundry,"foundry"))
	eco.complete_construction()
	var old := sim.to_dict()
	old.economy.erase("advanced_chapter")
	sim.from_dict(JSON.parse_string(JSON.stringify(old)))
	eco = sim.economy
	assert_eq(eco.antiquity_chapter(),1)
	assert_false(eco.select_recipe(mine,"iron_ore"))
	assert_false(eco.enter_chapter(2))
	assert_true(eco.equip_bronze("field"))
	assert_true(eco.enter_chapter(2))
	assert_false(eco.enter_chapter(2))
	assert_eq(eco.stock("books"),92.0)
	assert_true(eco.select_recipe(mine,"iron_ore"))
	assert_true(eco.select_recipe(foundry,"iron"))
	eco.stocks.iron = 0
	eco.stocks.iron_ore = 0
	eco.trained.miner = 1
	eco.trained.founder = 1
	eco.update(1)
	assert_true(eco.stock("iron") > 0)
	assert_eq(eco.building_limit("forum"),0)
	assert_false(eco.enter_chapter(3))
	eco.last_trade = 0
	assert_false(eco.enter_chapter(3))
	eco.update(15)
	assert_true(eco.enter_chapter(3))
	var loaded := _sim()
	loaded.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())))
	assert_eq(loaded.economy.antiquity_chapter(),3)
	assert_true(loaded.economy.def_of(foundry).produces.has("iron"))
	assert_true(loaded.economy.build(_spot(loaded,"forum"),"forum"))
	assert_false(loaded.economy.enter_chapter(3))


func test_canal_preview_valve_water_shortage_and_reload() -> void:
	var sim := _sim()
	var eco := sim.economy
	eco.townhall_level = 10
	eco.first_ingot = 1
	eco._rebuild_caches()
	for res in eco.BASE_RESOURCES:
		eco.stocks[res] = 100
	var field := _spot(sim,"field")
	assert_true(eco.build(field,"field"))
	eco.complete_construction()
	var cistern := -1
	for cell in sim.planet.grid.neighbors[field]:
		if eco.can_build(cell,"cistern") == "":
			cistern = cell
			break
	assert_true(cistern >= 0)
	assert_true(eco.build(cistern,"cistern"))
	assert_false(eco.connect_canal(field,cistern))
	eco.complete_construction()
	assert_false(eco.connect_canal(field,cistern))
	eco.advanced_chapter = 2
	var wood := eco.stock("wood")
	assert_true(eco.connect_canal(field,cistern))
	assert_false(eco.connect_canal(field,cistern))
	assert_eq(eco.stock("wood"),wood-6)
	eco.trained.farmer = 2
	eco.elapsed_days = 6
	sim.tick = sim.ticks_per_day*6
	var dry := eco.forecast(-1,0.01)
	var wet := eco.forecast(-1,0.01,-1,field,true)
	assert_true(is_equal_approx(wet.outputs[field].grain, dry.outputs[field].grain*1.5))
	assert_true(is_equal_approx(wet.net.water,dry.net.water-2))
	assert_false(eco.canals[field].open)
	assert_true(eco.set_valve(field,true))
	eco.update(0.01)
	assert_true(is_equal_approx(eco.building_rate(field).grain, wet.outputs[field].grain))
	var loaded := _sim()
	loaded.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())))
	eco = loaded.economy
	assert_true(eco.canals[field].open)
	loaded.advance_offline(10,10,3600,1)
	assert_true(eco.building_inputs(field).water > 0)
	eco.stocks.water = 0.0
	assert_eq(eco.forecast(-1,0.01).inputs[field].water,0.0)
	assert_true(eco.set_valve(field,false))
	assert_false(eco.forecast(-1,0.01).inputs[field].has("water"))
	assert_true(eco.demolish(cistern))
	assert_false(eco.canals.has(field))
