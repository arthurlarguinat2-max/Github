## Economy: stocks, buildings, workers and population.
##
## Pure logic (no node, no rendering), driven by Simulation with a time step
## expressed in days, so the same code serves live play (tiny steps) and
## offline progress (big steps). Rules and numbers come from data/*.json.
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
const BASE_RESOURCES := ["food", "wood", "stone"]

var planet  # PlanetState (untyped to avoid a cyclic preload)
var defs: Dictionary = {}
var terrain_defs: Dictionary = {}
var settings: Dictionary = {}

var stocks: Dictionary = {}
var population := 0
var village_center := -1
## Net change per day of each resource, measured during the last update.
var rates: Dictionary = {}

var _building_cells: Array[int] = []
var _territory: Dictionary = {}
var _staffing: Dictionary = {}        # cell -> 0..1
var _building_rates: Dictionary = {}  # cell -> {resource: per day}


func setup(p_planet, p_defs: Dictionary, p_terrain_defs: Dictionary, p_settings: Dictionary) -> void:
	planet = p_planet
	defs = p_defs
	terrain_defs = p_terrain_defs
	settings = p_settings
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


func in_territory(cell: int) -> bool:
	return _territory.has(cell)


func stock(res: String) -> float:
	return float(stocks.get(res, 0.0))


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
	_compute_staffing()
	var new_rates := {}
	for res in BASE_RESOURCES:
		new_rates[res] = 0.0
	_building_rates.clear()
	for cell in _building_cells:
		var def := def_of(cell)
		var produces: Dictionary = def.get("produces", {})
		if produces.is_empty():
			continue
		var mult: float = _staffing.get(cell, 0.0)
		if def.get("fertility_bonus", false):
			mult *= 0.4 + planet.fertility[cell]
		var out := {}
		for res in produces:
			var amount := float(produces[res]) * mult * dt_days
			if def.has("extracts"):
				amount = _extract(cell, str(def.extracts), amount)
			stocks[res] = stock(res) + amount
			out[res] = amount / dt_days
			new_rates[res] = float(new_rates.get(res, 0.0)) + out[res]
		_building_rates[cell] = out
	var eat := population * float(settings.get("food_per_person_per_day", 1.0))
	stocks["food"] = maxf(0.0, stock("food") - eat * dt_days)
	new_rates["food"] = float(new_rates["food"]) - eat
	rates = new_rates


## Once per in-game day: nature regrows, population grows or shrinks.
func daily_update() -> void:
	_regrow()
	var capacity := housing()
	if stock("food") <= 0.0 and population > 0:
		var loss := maxi(1, ceili(population * float(settings.get("famine_loss", 0.1))))
		population = maxi(0, population - loss)
		alert.emit("ALERT_FAMINE")
	elif population > capacity:
		population -= 1
		alert.emit("ALERT_HOMELESS")
	elif population < capacity:
		population += mini(capacity - population, maxi(1, _growth_bonus()))


# --- Save --------------------------------------------------------------------

func to_dict() -> Dictionary:
	var saved_stocks := {}
	for res in stocks:
		saved_stocks[res] = snappedf(stock(res), 0.01)
	return {"stocks": saved_stocks, "population": population, "village_center": village_center}


func from_dict(data: Dictionary) -> void:
	stocks = {}
	for res in BASE_RESOURCES:
		stocks[res] = 0.0
	var saved: Dictionary = data.get("stocks", {})
	for res in saved:
		stocks[str(res)] = float(saved[res])
	population = maxi(int(data.get("population", 0)), 0)
	village_center = int(data.get("village_center", -1))
	_rebuild_caches()


# --- Internals ---------------------------------------------------------------

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
	var total := 0
	for cell in _building_cells:
		total += int(def_of(cell).get("growth_bonus", 0))
	return total


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
		for nb in planet.grid.neighbors[i]:
			if not terrain_defs.get(planet.terrain[nb], {}).get("water", false):
				land += 1
			if planet.terrain[nb] == "forest":
				wood_near = true
		var score: float = planet.fertility[i] + 0.06 * land + (0.15 if wood_near else 0.0)
		if score > best_score:
			best_score = score
			best = i
	return best
