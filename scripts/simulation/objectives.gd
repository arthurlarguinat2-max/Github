## Goals: evaluates progress from the simulation state and grants rewards.
## Pure logic; definitions come from data/objectives.json.
extends RefCounted


## [current, target] for one objective definition.
static func progress(sim, obj: Dictionary) -> Array:
	var eco = sim.economy
	var target := float(obj.get("value", 1))
	var current := 0.0
	match str(obj.get("type", "")):
		"population":
			current = eco.population
		"townhall":
			current = eco.townhall_level
		"trained":
			current = eco.trained_total()
		"building":
			current = sim.planet.buildings.count(str(obj.get("target", "")))
		"buildings_total":
			current = eco.building_cells().size()
		"happiness":
			current = eco.happiness
		"health":
			current = eco.health
		"day":
			current = sim.day()
		"stock":
			current = eco.stock(str(obj.get("target", "")))
	return [minf(current, target), target]


static func is_done(sim, obj: Dictionary) -> bool:
	var p := progress(sim, obj)
	return p[0] >= p[1]


## Marks newly reached objectives as completed, gives their rewards and
## returns their ids.
static func check(sim, objectives: Array) -> Array:
	var newly: Array = []
	for obj in objectives:
		var id := str(obj.get("id", ""))
		if id == "" or id in sim.completed_objectives:
			continue
		if is_done(sim, obj):
			sim.completed_objectives.append(id)
			var reward: Dictionary = obj.get("reward", {})
			for res in reward:
				sim.economy.stocks[res] = sim.economy.stock(res) + float(reward[res])
			newly.append(id)
	return newly
