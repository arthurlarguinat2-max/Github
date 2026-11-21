## Economy: stocks, buildings, production chains, workers, population needs.
##
## Pure logic (no node, no rendering), driven by Simulation with a time step
## expressed in days, so the same code serves live play (tiny steps) and
## offline progress (big steps). Rules and numbers come from data/*.json.
##
## Each building may:
##   produce   resources per day (scaled by workers, fertility, tools, happiness),
##   consume   inputs per day (production slows down when inputs run out),
##   extract   from deposits on its cell and neighbours,
##   give      housing, happiness or health to the whole village.
extends RefCounted

## Buildings changed: rendering and UI must refresh.
signal changed
## Something the player should know about (localization key).
signal alert(key: String)

const ERR_UNKNOWN := "BUILD_ERR_UNKNOWN"
const ERR_OCCUPIED := "BUILD_ERR_OCCUPIED"
const ERR_TERRAIN := "BUILD_ERR_TERRAIN"
const ERR_DEPOSIT := "BUILD_ERR_DEPOSIT"
const ERR_TERRITORY := "BUILD_ERR_TERRITORY"
const ERR_COST := "BUILD_ERR_COST"
const BASE_RESOURCES := ["food", "wood", "stone", "water", "grain", "flour", "tools"]

var planet  # PlanetState (untyped to avoid a cyclic preload)
var defs: Dictionary = {}
var terrain_defs: Dictionary = {}
var settings: Dictionary = {}

var stocks: Dictionary = {}
var population := 0
var village_center := -1
## Village well-being, 0..100.
var happiness := 60.0
var health := 80.0
## Net change per day of each resource, measured during the last update.
var rates: Dictionary = {}

var _building_cells: Array[int] = []
var _territory: Dictionary = {}
var _staffing: Dictionary = {}        # cell -> 0..1
var _building_rates: Dictionary = {}  # cell -> {resource: produced per day}
var _building_inputs: Dictionary = {} # cell -> {resource: consumed per day}
var _waiting: Dictionary = {}         # cell -> true when inputs are missing
var _short_food := false              # Ran out of food since the last daily update.
var _short_water := false


func setup(p_planet, p_defs: Dictionary, p_terrain_defs: Dictionary, p_settings: Dictionary) -> void:
	planet = p_planet
	defs = p_defs
	terrain_defs = p_terrain_defs
	settings = p_settings
	var wb := _wb()
	happiness = float(wb.get("happiness_start", 60.0))
	health = float(wb.get("health_start", 80.0))
	for res in BASE_RESOURCES:
		if not stocks.has(res):
			stocks[res] = 0.0
	_rebuild_caches()


# --- Queries -----------------------------------------------------------------

func building_at(cell: int) -> String:
	return planet.buildings[cell]


func building_cells() -> Array[int]:
	return _building_cells


func def_of(cell: int) -> Dictionary:
	return defs.get(planet.buildings[cell], {})


func housing() -> int:
	var total := 0
	for cell in _building_cells:
		total += int(def_of(cell).get("housing", 0))
	return total


func jobs() -> int:
	var total := 0
	for cell in _building_cells:
		total += int(def_of(cell).get("workers", 0))
	return total


func employed() -> int:
	return mini(population, jobs())


func workers_at(cell: int) -> int:
	return roundi(float(_staffing.get(cell, 0.0)) * int(def_of(cell).get("workers", 0)))


## Per-day output of a building measured during the last update.
func building_rate(cell: int) -> Dictionary:
	return _building_rates.get(cell, {})


## Per-day inputs used by a building during the last update.
func building_inputs(cell: int) -> Dictionary:
	return _building_inputs.get(cell, {})


## True when a converter (mill, bakery...) is waiting for its inputs.
func is_waiting(cell: int) -> bool:
	return _waiting.has(cell)


func in_territory(cell: int) -> bool:
	return _territory.has(cell)


func stock(res: String) -> float:
	return float(stocks.get(res, 0.0))


## Production multiplier from happiness: 0.6 (miserable) .. 1.2 (joyful).
func productivity() -> float:
	return 0.6 + 0.6 * clampf(happiness, 0.0, 100.0) / 100.0


func can_afford(cost: Dictionary) -> bool:
	for res in cost:
		if stock(res) + 0.0001 < float(cost[res]):
			return false
	return true


## "" when `id` can be built on `cell`, otherwise the localization key of the reason.
## Order matters: the UI hides buildings that can never go on this cell.
func can_build(cell: int, id: String) -> String:
	if not defs.has(id):
		return ERR_UNKNOWN
	if planet.buildings[cell] != "":
		return ERR_OCCUPIED
	var def: Dictionary = defs[id]
	if not (planet.terrain[cell] in def.get("terrains", [])):
		return ERR_TERRAIN
	if def.has("extracts") and not has_deposit(cell, str(def.extracts)):
		return ERR_DEPOSIT
	if not _territory.has(cell):
		return ERR_TERRITORY
	if not can_afford(def.get("cost", {})):
		return ERR_COST
	return ""


func has_deposit(cell: int, res: String) -> bool:
	for c in _cell_and_neighbors(cell):
		if float(planet.resources[c].get(res, 0.0)) > 0.0:
			return true
	return false


func near_water(cell: int) -> bool:
	for nb in planet.grid.neighbors[cell]:
		if terrain_defs.get(planet.terrain[nb], {}).get("water", false):
			return true
	return false


## What pushes happiness up or down right now: [[localization key, points], ...].
func happiness_factors() -> Array:
	var wb := _wb()
	var factors: Array = [["WB_BASE", float(wb.get("happiness_base", 50))]]
	var leisure := minf(_sum_bonus("happiness"), float(wb.get("leisure_cap", 30)))
	if leisure > 0.0:
		factors.append(["WB_LEISURE", leisure])
	if _short_food or stock("food") <= 0.0:
		factors.append(["WB_FAMINE", float(wb.get("famine_happiness", -25))])
	if _short_water or stock("water") <= 0.0:
		factors.append(["WB_THIRST", float(wb.get("thirst_happiness", -20))])
	if population > housing():
		factors.append(["WB_HOMELESS", float(wb.get("homeless_happiness", -15))])
	if population > 0 and population - employed() > population * 0.4:
		factors.append(["WB_UNEMPLOYED", float(wb.get("unemployment_happiness", -8))])
	var health_effect := (health - 60.0) * 0.2
	if absf(health_effect) >= 1.0:
		factors.append(["WB_HEALTH", health_effect])
	return factors


## What pushes health up or down right now.
func health_factors() -> Array:
	var wb := _wb()
	var factors: Array = [["WB_BASE", float(wb.get("health_base", 65))]]
	var care := minf(_sum_bonus("health"), float(wb.get("health_bonus_cap", 30)))
	if care > 0.0:
		factors.append(["WB_CARE", care])
	if _short_food or stock("food") <= 0.0:
		factors.append(["WB_FAMINE", float(wb.get("famine_health", -20))])
	if _short_water or stock("water") <= 0.0:
		factors.append(["WB_THIRST", float(wb.get("thirst_health", -30))])
	if population > housing():
		factors.append(["WB_CROWDING", float(wb.get("crowding_health", -10))])
	return factors


static func target_of(factors: Array) -> float:
	var total := 0.0
	for f in factors:
		total += float(f[1])
	return clampf(total, 0.0, 100.0)


# --- Actions -----------------------------------------------------------------

func build(cell: int, id: String) -> bool:
	if can_build(cell, id) != "":
		return false
	var cost: Dictionary = defs[id].get("cost", {})
	for res in cost:
		stocks[res] = stock(res) - float(cost[res])
	_place(cell, id)
	return true


## Removes a building and refunds half of its cost. The village center stays.
func demolish(cell: int) -> bool:
	var id: String = planet.buildings[cell]
	if id == "" or cell == village_center:
		return false
	var cost: Dictionary = defs.get(id, {}).get("cost", {})
	for res in cost:
		stocks[res] = stock(res) + float(cost[res]) * 0.5
	planet.buildings[cell] = ""
	_rebuild_caches()
	changed.emit()
	return true


## New game: starting stocks, population and free buildings on a good spot.
func found_village(start: Dictionary) -> void:
	stocks = {}
	for res in BASE_RESOURCES:
		stocks[res] = 0.0
	var start_stocks: Dictionary = start.get("stocks", {})
	for res in start_stocks:
		stocks[res] = float(start_stocks[res])
	population = int(start.get("population", 4))
	var to_place: Array = start.get("buildings", ["campfire", "hut"])
	if to_place.is_empty():
		return
	village_center = _pick_start_cell(str(to_place[0]))
	if village_center < 0:
		return
	planet.buildings[village_center] = str(to_place[0])
	var candidates: Array = Array(planet.grid.neighbors[village_center])
	candidates.sort_custom(func(a, b): return planet.fertility[a] > planet.fertility[b])
	for k in range(1, to_place.size()):
		var id := str(to_place[k])
		for c in candidates:
			if planet.buildings[c] == "" and planet.terrain[c] in defs.get(id, {}).get("terrains", []):
				planet.buildings[c] = id
				break
	_rebuild_caches()
	changed.emit()


# --- Time --------------------------------------------------------------------

## Continuous production and consumption over `dt_days` (can be a fraction).
func update(dt_days: float) -> void:
	if dt_days <= 0.0:
		return
	var wb := _wb()
	_compute_staffing()
	var new_rates := {}
	for res in BASE_RESOURCES:
		new_rates[res] = 0.0
	_building_rates.clear()
	_building_inputs.clear()
	_waiting.clear()
	var village_productivity := productivity()
	for cell in _building_cells:
		var def := def_of(cell)
		var produces: Dictionary = def.get("produces", {})
		if produces.is_empty():
			continue
		var mult: float = float(_staffing.get(cell, 0.0)) * village_productivity
		if mult <= 0.0:
			continue
		if def.get("fertility_bonus", false):
			mult *= 0.4 + planet.fertility[cell]
		if def.has("water_bonus") and near_water(cell):
			mult *= float(def.water_bonus)
		if def.get("tool_bonus", false) and stock("tools") > 0.0:
			mult *= float(wb.get("tool_bonus", 1.25))
			var worn := minf(stock("tools"), float(wb.get("tool_use_per_day", 0.05)) * dt_days)
			stocks["tools"] = stock("tools") - worn
			new_rates["tools"] = float(new_rates["tools"]) - worn / dt_days

		# Inputs: the scarcest one limits the whole production.
		var consumes: Dictionary = def.get("consumes", {})
		var supply := 1.0
		for res in consumes:
			var need := float(consumes[res]) * mult * dt_days
			if need > 0.0:
				supply = minf(supply, stock(res) / need)
		if supply < 0.999 and not consumes.is_empty():
			_waiting[cell] = true
		if supply <= 0.0:
			continue
		var inputs := {}
		for res in consumes:
			var used := float(consumes[res]) * mult * dt_days * supply
			stocks[res] = maxf(0.0, stock(res) - used)
			inputs[res] = used / dt_days
			new_rates[res] = float(new_rates.get(res, 0.0)) - inputs[res]
		var outputs := {}
		for res in produces:
			var amount := float(produces[res]) * mult * dt_days * supply
			if def.has("extracts"):
				amount = _extract(cell, str(def.extracts), amount)
			stocks[res] = stock(res) + amount
			outputs[res] = amount / dt_days
			new_rates[res] = float(new_rates.get(res, 0.0)) + outputs[res]
		_building_rates[cell] = outputs
		_building_inputs[cell] = inputs

	# People eat and drink.
	_consume_needs("food", float(settings.get("food_per_person_per_day", 1.0)), dt_days, new_rates)
	_consume_needs("water", float(settings.get("water_per_person_per_day", 1.0)), dt_days, new_rates)
	rates = new_rates


## Once per in-game day: nature regrows, well-being evolves, population changes.
func daily_update() -> void:
	_regrow()
	var wb := _wb()
	happiness += (target_of(happiness_factors()) - happiness) * float(wb.get("happiness_speed", 0.25))
	health += (target_of(health_factors()) - health) * float(wb.get("health_speed", 0.2))
	var capacity := housing()
	if stock("food") <= 0.0 and population > 0:
		var loss := maxi(1, ceili(population * float(settings.get("famine_loss", 0.1))))
		population = maxi(0, population - loss)
		alert.emit("ALERT_FAMINE")
	elif stock("water") <= 0.0 and population > 0:
		population -= 1
		alert.emit("ALERT_THIRST")
	elif population > capacity:
		population -= 1
		alert.emit("ALERT_HOMELESS")
	elif health < 25.0 and population > 0:
		population -= 1
		alert.emit("ALERT_SICKNESS")
	elif happiness < 20.0 and population > 0:
		population -= 1
		alert.emit("ALERT_UNHAPPY")
	elif population < capacity and happiness >= 40.0 and health >= 40.0:
		var births := maxi(1, _growth_bonus()) + (1 if happiness >= 75.0 else 0)
		population += mini(capacity - population, births)
	_short_food = false
	_short_water = false


# --- Save --------------------------------------------------------------------

func to_dict() -> Dictionary:
	var saved_stocks := {}
	for res in stocks:
		saved_stocks[res] = snappedf(stock(res), 0.01)
	return {
		"stocks": saved_stocks,
		"population": population,
		"village_center": village_center,
		"happiness": snappedf(happiness, 0.01),
		"health": snappedf(health, 0.01),
	}


func from_dict(data: Dictionary) -> void:
	stocks = {}
	for res in BASE_RESOURCES:
		stocks[res] = 0.0
	var saved: Dictionary = data.get("stocks", {})
	for res in saved:
		stocks[str(res)] = float(saved[res])
	# Saves from before Phase 3 had no water: give a fair amount to start with.
	if not saved.has("water"):
		stocks["water"] = 40.0
	population = maxi(int(data.get("population", 0)), 0)
	village_center = int(data.get("village_center", -1))
	var wb := _wb()
	happiness = clampf(float(data.get("happiness", wb.get("happiness_start", 60.0))), 0.0, 100.0)
	health = clampf(float(data.get("health", wb.get("health_start", 80.0))), 0.0, 100.0)
	_rebuild_caches()


# --- Internals ---------------------------------------------------------------

func _wb() -> Dictionary:
	return settings.get("wellbeing", {})


func _consume_needs(res: String, per_person: float, dt_days: float, new_rates: Dictionary) -> void:
	var need := population * per_person
	if need <= 0.0:
		return
	if stock(res) < need * dt_days:
		if res == "food":
			_short_food = true
		else:
			_short_water = true
	stocks[res] = maxf(0.0, stock(res) - need * dt_days)
	new_rates[res] = float(new_rates.get(res, 0.0)) - need


## Sum of a village bonus ("happiness", "health", "growth_bonus") from
## buildings, scaled by how well each one is staffed.
func _sum_bonus(key: String) -> float:
	var total := 0.0
	for cell in _building_cells:
		var value := float(def_of(cell).get(key, 0.0))
		if value != 0.0:
			total += value * float(_staffing.get(cell, 1.0 if int(def_of(cell).get("workers", 0)) == 0 else 0.0))
	return total


func _place(cell: int, id: String) -> void:
	planet.buildings[cell] = id
	_rebuild_caches()
	changed.emit()


func _rebuild_caches() -> void:
	_building_cells.clear()
	if planet == null:
		return
	for i in planet.cell_count():
		if planet.buildings[i] != "":
			_building_cells.append(i)
	_building_cells.sort_custom(func(a, b):
		var pa := int(def_of(a).get("priority", 9))
		var pb := int(def_of(b).get("priority", 9))
		return pa < pb or (pa == pb and a < b))
	_territory = {}
	for cell in _building_cells:
		_mark_territory(cell, int(def_of(cell).get("territory", 2)))
	_compute_staffing()


func _mark_territory(start: int, radius: int) -> void:
	_territory[start] = true
	var seen := {start: true}
	var frontier: Array = [start]
	for step in radius:
		var next: Array = []
		for c in frontier:
			for nb in planet.grid.neighbors[c]:
				if not seen.has(nb):
					seen[nb] = true
					_territory[nb] = true
					next.append(nb)
		frontier = next


func _compute_staffing() -> void:
	_staffing.clear()
	var free := population
	for cell in _building_cells:
		var need := int(def_of(cell).get("workers", 0))
		if need <= 0:
			_staffing[cell] = 1.0
			continue
		var got := mini(need, free)
		free -= got
		_staffing[cell] = float(got) / float(need)


func _cell_and_neighbors(cell: int) -> Array:
	var cells: Array = [cell]
	cells.append_array(Array(planet.grid.neighbors[cell]))
	return cells


## Takes up to `wanted` of `res` from the cell, then its neighbours.
## Returns the amount actually taken (deposits run out).
func _extract(cell: int, res: String, wanted: float) -> float:
	var remaining := wanted
	for c in _cell_and_neighbors(cell):
		if remaining <= 0.0:
			break
		var deposit: Dictionary = planet.resources[c]
		var available := float(deposit.get(res, 0.0))
		if available <= 0.0:
			continue
		var take := minf(available, remaining)
		if available - take <= 0.001:
			deposit.erase(res)
		else:
			deposit[res] = available - take
		remaining -= take
	return wanted - remaining


func _regrow() -> void:
	for i in planet.cell_count():
		var regrow: Dictionary = terrain_defs.get(planet.terrain[i], {}).get("regrow", {})
		for res in regrow:
			var spec: Array = regrow[res]
			var current := float(planet.resources[i].get(res, 0.0))
			if current < float(spec[1]):
				planet.resources[i][res] = minf(float(spec[1]), current + float(spec[0]))


func _growth_bonus() -> int:
	return int(_sum_bonus("growth_bonus"))


## Most fertile land cell (with some land around) where `id` is allowed.
func _pick_start_cell(id: String) -> int:
	var allowed: Array = defs.get(id, {}).get("terrains", ["plains"])
	var best := -1
	var best_score := -INF
	for i in planet.cell_count():
		if not (planet.terrain[i] in allowed):
			continue
		var land := 0
		var wood_near := false
		var water_near := false
		for nb in planet.grid.neighbors[i]:
			if terrain_defs.get(planet.terrain[nb], {}).get("water", false):
				water_near = true
			else:
				land += 1
			if planet.terrain[nb] == "forest":
				wood_near = true
		var score: float = planet.fertility[i] + 0.06 * land + (0.15 if wood_near else 0.0) + (0.1 if water_near else 0.0)
		if score > best_score:
			best_score = score
			best = i
	return best
