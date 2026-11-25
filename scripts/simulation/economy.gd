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
## A construction site (or an upgrade) is finished.
signal construction_done(cell: int)
## The town hall reached a new level.
signal level_up(level: int)
## A villager finished training for a profession.
signal training_done(profession: String)

const ERR_UNKNOWN := "BUILD_ERR_UNKNOWN"
const ERR_OCCUPIED := "BUILD_ERR_OCCUPIED"
const ERR_TERRAIN := "BUILD_ERR_TERRAIN"
const ERR_DEPOSIT := "BUILD_ERR_DEPOSIT"
const ERR_TERRITORY := "BUILD_ERR_TERRITORY"
const ERR_COST := "BUILD_ERR_COST"
const ERR_LOCKED := "BUILD_ERR_LOCKED"
const ERR_LIMIT := "BUILD_ERR_LIMIT"
const ERR_BUILDERS := "BUILD_ERR_BUILDERS"
const ERR_NO_VILLAGER := "TRAIN_ERR_NO_VILLAGER"
const ERR_SLOTS := "TRAIN_ERR_SLOTS"
const ERR_REQUIREMENT := "TH_ERR_REQUIREMENT"
const ERR_MAX := "TH_ERR_MAX"
const ERR_BUSY := "TH_ERR_BUSY"
const BASE_RESOURCES := ["food", "wood", "stone", "water", "grain", "flour", "tools", "clay", "bricks", "pots", "boards", "frames", "flax", "linen", "paper", "books", "copper", "tin", "bronze", "iron_ore", "iron"]

var planet  # PlanetState (untyped to avoid a cyclic preload)
var defs: Dictionary = {}
var terrain_defs: Dictionary = {}
var settings: Dictionary = {}

var stocks: Dictionary = {}
var recipe_choices: Dictionary = {}
const SEASONS := ["S_SPRING", "S_SUMMER", "S_FALL", "S_WINTER"]
const SEASON_DAYS := 6
var elapsed_days := 0
var sowing := {}
var canals := {}
const CANAL_COST := {"wood": 6, "stone": 8}
const IRRIGATION_BOOST := [0.25, 0.50, 0.25, 0.10]


func valid_canal(field: int, source: int) -> bool:
	return antiquity_chapter() >= 2 and field >= 0 and field < planet.cell_count() and source in planet.grid.neighbors[field] and building_at(field) == "field" and building_at(source) == "cistern" and is_active(field) and is_active(source)


func connect_canal(field: int, source: int) -> bool:
	if canals.has(field) or not valid_canal(field, source) or not can_afford(CANAL_COST):
		return false
	_pay(CANAL_COST)
	canals[field] = {"source": source, "open": false}
	changed.emit()
	return true


func set_valve(field: int, opened: bool) -> bool:
	if not canals.has(field) or not valid_canal(field, canals[field].source):
		return false
	canals[field].open = opened
	return true



func season_index() -> int:
	return floori(elapsed_days / float(SEASON_DAYS)) % SEASONS.size()

## Negative before study, zero when complete, otherwise remaining village days.
var bronze_study := -1.0
var first_ingot := 0.0
var advanced_chapter := 0
const CHAPTER_COSTS := {2: {"books": 8, "bronze": 6}, 3: {"iron": 10, "paper": 12, "bricks": 16}}


func antiquity_chapter() -> int:
	return maxi(1, advanced_chapter) if first_ingot >= 1.0 else 0


func enter_chapter(next: int) -> bool:
	if next != antiquity_chapter() + 1 or not CHAPTER_COSTS.has(next):
		return false
	if (next == 2 and bronze_equipment.is_empty()) or (next == 3 and last_trade < 0):
		return false
	if not can_afford(CHAPTER_COSTS[next]):
		return false
	_pay(CHAPTER_COSTS[next])
	advanced_chapter = next
	return true

var bronze_equipment := {}
const TRADE_OFFERS := [
	{"sell": "pots", "amount": 8, "buy": "tin", "receive": 4},
	{"sell": "linen", "amount": 6, "buy": "copper", "receive": 9},
	{"sell": "books", "amount": 4, "buy": "tools", "receive": 6},
	{"sell": "bronze", "amount": 3, "buy": "frames", "receive": 5},
]
var market_cell := -1
var market_days := 0
var last_trade := -1
var trade_reserves := {}
var trade_auto := {}
var pantry_days := 0
var seed_target := 0
var extra_plots := {}
var orders := {}
var contract := {}
var contract_visit := -1
const CONTRACT_UNITS := {"food": 6, "grain": 4, "pots": 2}
const SEED_COST := 4


func food_demand() -> float:
	return population * float(settings.get("food_per_person_per_day", 1.0))


func protected_stock(res: String) -> float:
	var keep := float(trade_reserves.get(res, 0))
	if res == "food":
		keep = maxf(keep, pantry_days * food_demand())
	if res == "grain":
		keep = maxf(keep, seed_target)
	return keep


func sow_extra_plots() -> void:
	extra_plots.clear()
	var budget := minf(stock("grain"), seed_target)
	for cell in _building_cells:
		if budget < SEED_COST:
			break
		if building_at(cell) == "field" and is_active(cell):
			budget -= SEED_COST
			stocks.grain -= SEED_COST
			extra_plots[cell] = true


func set_order(cell: int, kind: String, quantity: int) -> bool:
	if cell not in _building_cells or not is_active(cell) or bronze_study != 0.0:
		return false
	var def := def_of(cell)
	if not def.has("consumes") or def.get("produces", {}).size() != 1:
		return false
	if kind == "auto":
		orders.erase(cell)
	elif kind in ["target", "batch"] and quantity > 0:
		orders[cell] = {"kind": kind, "amount": float(quantity), "res": def.produces.keys()[0]}
	else:
		return false
	return true


func mentoring_days(cell: int) -> float:
	for student in training:
		if int(student.get("mentor", -1)) == cell:
			return float(student.left) / _train_speed()
	return 0.0


func teaching(cell: int) -> bool:
	return mentoring_days(cell) > 0.0


func apprentice_blocker(cell: int) -> String:
	if bronze_study != 0.0 or cell not in _building_cells or not is_active(cell):
		return ERR_LOCKED
	var profession := str(def_of(cell).get("profession", ""))
	if teaching(cell) or float(_allocation(preferred_cell).get(cell, 0)) <= 0 or trained_count(profession) == 0:
		return "POL_MENTOR_BUSY"
	if idle_villagers() <= 0:
		return ERR_NO_VILLAGER
	if training.size() >= training_slots():
		return ERR_SLOTS
	return ""


func apprentice(cell: int) -> bool:
	if apprentice_blocker(cell) != "":
		return false
	training.append({"profession": def_of(cell).profession, "mentor": cell, "left": 1.0})
	return true


func sign_contract(visit: int, res: String, lots: int) -> bool:
	if antiquity_chapter() == 0 or not caravan_present() or visit != caravan_visit() or visit == contract_visit or not contract.is_empty():
		return false
	if not CONTRACT_UNITS.has(res) or lots not in [1, 2] or workers_at(market_cell) <= 0:
		return false
	contract_visit = visit
	contract = {"res": res, "amount": lots * int(CONTRACT_UNITS[res]), "tools": lots * 2, "due": elapsed_days + 3}
	return true


func delivery_blocker() -> String:
	if contract.is_empty() or elapsed_days > int(contract.due) or not caravan_present():
		return "POL_WAIT_CARAVAN"
	if workers_at(market_cell) <= 0:
		return "TRADE_NEED"
	var left := stock(contract.res) - float(contract.amount)
	if left < 0:
		return "TRADE_LOW"
	return "TRADE_FLOOR" if left < protected_stock(contract.res) else ""


func deliver_contract() -> bool:
	if delivery_blocker() != "":
		return false
	stocks[contract.res] -= float(contract.amount)
	stocks.tools = stock("tools") + float(contract.tools)
	contract.clear()
	return true


const STUDY_COST := {"books": 12}
const EQUIPMENT_COST := {"bronze": 1}
var population := 0
var village_center := -1
## Village well-being, 0..100.
var happiness := 60.0
var health := 80.0
## Territory radii are multiplied by this on planets with many small cells.
var territory_scale := 1
## Net change per day of each resource, measured during the last update.
var rates: Dictionary = {}

## Town hall progression (data/townhall.json) and professions (data/professions.json).
var townhall_levels: Array = []
var professions: Dictionary = {}
var townhall_level := 1
## Days left before the town hall upgrade is done (-1 = no upgrade running).
var townhall_upgrade_left := -1.0
## Trained villagers per profession.
var trained: Dictionary = {}
## Trainings in progress: [{"profession": id, "left": days}, ...]
var training: Array = []
## Construction sites: cell -> {"left": days, "total": days}
var construction: Dictionary = {}
var plans: Array = []
var preferred_cell := -1
var household_used := {}
var unmet_needs := {}


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
	var base: Dictionary = defs.get(planet.buildings[cell], {})
	if not recipe_choices.has(cell):
		return base
	var active := base.duplicate()
	active.merge(base.recipes[recipe_choices[cell]], true)
	return active


func select_recipe(cell: int, recipe: String) -> bool:
	if cell < 0 or cell >= planet.cell_count() or not is_active(cell):
		return false
	var base: Dictionary = defs.get(planet.buildings[cell], {})
	if not base.get("recipes", {}).has(recipe):
		return false
	if int(base.recipes[recipe].get("chapter", 0)) > antiquity_chapter():
		return false
	if planet.buildings[cell] == "field" and recipe_choices.get(cell, "grain") != recipe:
		sowing[cell] = 0.5
	if not def_of(cell).get("produces", {}).has(recipe):
		orders.erase(cell)
	if base.produces.has(recipe):
		recipe_choices.erase(cell)
	else:
		recipe_choices[cell] = recipe
	return true


func housing() -> int:
	var total := 0
	for cell in _building_cells:
		if not is_active(cell):
			continue
		if cell == village_center:
			total += int(level_def().get("housing", 4))
		else:
			total += int(def_of(cell).get("housing", 0))
	return total


func jobs() -> int:
	var total := profession_jobs("scholar")
	for cell in _building_cells:
		if is_active(cell):
			total += int(def_of(cell).get("workers", 0))
	return total


func employed() -> int:
	var total := 1 if bronze_study > 0.0 and study_blocker() == "" else 0
	for cell in _building_cells:
		total += workers_at(cell)
	return total


# --- Town hall, professions, construction ------------------------------------------

func level_def(level: int = -1) -> Dictionary:
	if level < 0:
		level = townhall_level
	for def in townhall_levels:
		if int(def.get("level", 0)) == level:
			return def
	return {"level": level, "housing": 4, "territory": 3, "builders": 1, "training_slots": 1, "buildings": {}, "professions": []}


func max_level() -> int:
	return maxi(townhall_levels.size(), 1)


## Max number of `id` allowed at the current level (0 = locked).
## Without progression data (old tests, tools), everything is allowed.
func building_limit(id: String) -> int:
	if int(defs.get(id, {}).get("chapter", 0)) > antiquity_chapter():
		return 0
	if defs.get(id, {}).get("requires_antiquity", false) and first_ingot < 1.0:
		return 0
	if defs.get(id, {}).get("bronze_research", false) and bronze_study != 0.0:
		return 0
	if townhall_levels.is_empty():
		return 999
	return int(level_def().get("buildings", {}).get(id, 0))


## First town hall level that unlocks `id` (0 if never).
func unlock_level(id: String) -> int:
	for def in townhall_levels:
		if int(def.get("buildings", {}).get(id, 0)) > 0:
			return int(def.level)
	return 0


func building_count(id: String) -> int:
	return planet.buildings.count(id)


func is_active(cell: int) -> bool:
	return not construction.has(cell)


## 0..1 progress of the construction site on `cell` (1 when finished).
func construction_progress(cell: int) -> float:
	if not construction.has(cell):
		return 1.0
	var site: Dictionary = construction[cell]
	return clampf(1.0 - float(site.left) / maxf(float(site.total), 0.001), 0.0, 1.0)


func construction_left(cell: int) -> float:
	return float(construction.get(cell, {}).get("left", 0.0)) / _build_speed()


func builders() -> int:
	return int(level_def().get("builders", 1))


func busy_builders() -> int:
	return construction.size() + (1 if townhall_upgrade_left >= 0.0 else 0)


func free_builders() -> int:
	return maxi(0, builders() - busy_builders())


func training_slots() -> int:
	return int(level_def().get("training_slots", 1))


func trained_total() -> int:
	var total := 0
	for p in trained:
		total += int(trained[p])
	return total


func trained_count(profession: String) -> int:
	return int(trained.get(profession, 0))


## Villagers without a profession (and not in training).
func idle_villagers() -> int:
	return maxi(0, population - trained_total() - training.size())


func is_profession_unlocked(profession: String) -> bool:
	if professions.get(profession, {}).get("requires_antiquity", false) and first_ingot < 1.0:
		return false
	if professions.get(profession, {}).get("bronze_research", false) and bronze_study != 0.0:
		return false
	if townhall_levels.is_empty():
		return true
	return profession in level_def().get("professions", [])


func profession_jobs(profession: String) -> int:
	if profession == "scholar":
		return 1 if bronze_study != 0.0 and open_library() else 0
	var total := 0
	for cell in _building_cells:
		if is_active(cell) and str(def_of(cell).get("profession", "")) == profession:
			total += int(def_of(cell).get("workers", 0))
	return total


func can_train(profession: String) -> String:
	if not professions.has(profession) or not is_profession_unlocked(profession):
		return ERR_LOCKED
	if idle_villagers() <= 0:
		return ERR_NO_VILLAGER
	if training.size() >= training_slots():
		return ERR_SLOTS
	if not can_afford(professions[profession].get("cost", {})):
		return ERR_COST
	return ""


func train(profession: String) -> bool:
	if can_train(profession) != "":
		return false
	var def: Dictionary = professions[profession]
	_pay(def.get("cost", {}))
	training.append({"profession": profession, "left": float(def.get("days", 0.25))})
	return true


## Sends a trained villager back to being a plain villager.
func untrain(profession: String) -> bool:
	if trained_count(profession) <= 0:
		return false
	trained[profession] = trained_count(profession) - 1
	return true


## "" when the town hall can be upgraded now, otherwise the reason key.
func can_upgrade_townhall() -> String:
	if townhall_level >= max_level():
		return ERR_MAX
	if townhall_upgrade_left >= 0.0:
		return ERR_BUSY
	var next := level_def(townhall_level + 1)
	if population < int(next.get("requires", {}).get("population", 0)):
		return ERR_REQUIREMENT
	if free_builders() <= 0:
		return ERR_BUILDERS
	if not can_afford(next.get("cost", {})):
		return ERR_COST
	return ""


func upgrade_townhall() -> bool:
	if can_upgrade_townhall() != "":
		return false
	var next := level_def(townhall_level + 1)
	_pay(next.get("cost", {}))
	townhall_upgrade_left = float(next.get("days", 1.0))
	return true


## Days left for the town hall upgrade, at the current building speed.
func townhall_upgrade_days_left() -> float:
	return maxf(townhall_upgrade_left, 0.0) / _build_speed()


## Skills (perks) unlocked so far, for the UI.
func perks() -> Array:
	var out: Array = []
	for def in townhall_levels:
		if int(def.get("level", 0)) <= townhall_level:
			out.append_array(def.get("perks", []))
	return out


## Test/tool helper: finishes every construction site at once.
func complete_construction() -> void:
	for cell in construction.keys():
		construction.erase(cell)
		construction_done.emit(cell)
	_rebuild_caches()


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
	if cell < 0 or cell >= planet.cell_count() or not defs.has(id):
		return ERR_UNKNOWN
	if planet.buildings[cell] != "":
		return ERR_OCCUPIED
	var def: Dictionary = defs[id]
	if not def.get("buildable", true):
		return ERR_UNKNOWN
	if building_limit(id) <= 0:
		return ERR_LOCKED
	if not (planet.terrain[cell] in def.get("terrains", [])):
		return ERR_TERRAIN
	if def.has("extracts") and not has_deposit(cell, str(def.extracts)):
		return ERR_DEPOSIT
	if building_count(id) >= building_limit(id):
		return ERR_LIMIT
	if not _territory.has(cell):
		return ERR_TERRITORY
	if float(def.get("build_days", 0.0)) > 0.0 and not townhall_levels.is_empty() and free_builders() <= 0:
		return ERR_BUILDERS
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
	var perk_joy := 0.0
	for perk in perks():
		perk_joy += float(perk.get("happiness", 0.0))
	if perk_joy > 0.0:
		factors.append(["WB_PERKS", perk_joy])
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
	_pay(defs[id].get("cost", {}))
	_start_site(cell, float(defs[id].get("build_days", 0.0)))
	_place(cell, id)
	return true


func plan_reason(cell: int, id: String) -> String:
	if plans.size() >= 2:
		return "PLAN_FULL"
	for plan in plans:
		if plan.cell == cell:
			return "PLAN_DUPLICATE"
	var reason := can_build(cell, id)
	return "" if reason in [ERR_BUILDERS, ERR_COST] else reason


func enqueue(cell: int, id: String) -> bool:
	if plan_reason(cell, id) != "":
		return false
	plans.append({"cell": cell, "id": id})
	return true


func _start_plans() -> void:
	while not plans.is_empty():
		var plan: Dictionary = plans[0]
		if can_build(plan.cell, plan.id) != "":
			break
		plans.pop_front()
		build(plan.cell, plan.id)


## Building this one can be upgraded into ("" if none).
func upgrade_target(cell: int) -> String:
	return str(def_of(cell).get("upgrade_to", ""))


func upgrade_cost(cell: int) -> Dictionary:
	return defs.get(upgrade_target(cell), {}).get("upgrade_cost", {})


## "" when the building on `cell` can be upgraded now, else the reason key.
func can_upgrade(cell: int) -> String:
	var target := upgrade_target(cell)
	if target == "" or not defs.has(target):
		return ERR_UNKNOWN
	if not is_active(cell):
		return ERR_BUSY
	if building_limit(target) <= 0:
		return ERR_LOCKED
	if building_count(target) >= building_limit(target):
		return ERR_LIMIT
	if not townhall_levels.is_empty() and free_builders() <= 0:
		return ERR_BUILDERS
	if not can_afford(upgrade_cost(cell)):
		return ERR_COST
	return ""


func upgrade(cell: int) -> bool:
	if can_upgrade(cell) != "":
		return false
	var target := upgrade_target(cell)
	_pay(upgrade_cost(cell))
	_start_site(cell, float(defs[target].get("build_days", 0.0)))
	_place(cell, target)
	return true


## Removes a building and refunds half of its cost. The village center stays.
func demolish(cell: int) -> bool:
	var id: String = planet.buildings[cell]
	if id == "" or cell == village_center:
		return false
	var cost: Dictionary = defs.get(id, {}).get("cost", {})
	for res in cost:
		stocks[res] = stock(res) + float(cost[res]) * 0.5
	if preferred_cell == cell:
		preferred_cell = -1
	for field in canals.keys():
		if field == cell or canals[field].source == cell:
			canals.erase(field)
	orders.erase(cell)
	extra_plots.erase(cell)
	for i in range(training.size() - 1, -1, -1):
		if int(training[i].get("mentor", -1)) == cell:
			training.remove_at(i)
	recipe_choices.erase(cell)
	sowing.erase(cell)
	planet.buildings[cell] = ""
	construction.erase(cell)
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
	trained = {}
	var start_trained: Dictionary = start.get("trained", {})
	for p in start_trained:
		trained[str(p)] = int(start_trained[p])
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

func open_library() -> bool:
	if townhall_level < 10:
		return false
	for cell in _building_cells:
		if planet.buildings[cell] == "library" and is_active(cell):
			return true
	return false


func study_blocker() -> String:
	if not open_library():
		return "ANT_LIBRARY"
	if trained_count("scholar") == 0:
		return "ANT_SCHOLAR"
	if bronze_study < 0.0 and not can_afford(STUDY_COST):
		return "ANT_BOOKS"
	return ""


func start_bronze_study() -> bool:
	if bronze_study >= 0.0 or study_blocker() != "":
		return false
	_pay(STUDY_COST)
	bronze_study = 2.0
	return true


func equip_bronze(sector: String) -> bool:
	if first_ingot < 1.0 or sector not in ["field", "quarry"] or bronze_equipment.has(sector) or not can_afford(EQUIPMENT_COST):
		return false
	_pay(EQUIPMENT_COST)
	bronze_equipment[sector] = true
	return true


func caravan_present() -> bool:
	return market_cell >= 0 and is_active(market_cell) and market_days % 3 == 0


func caravan_visit() -> int:
	return floori(market_days / 3.0)


func caravan_offer(visit: int) -> Dictionary:
	return TRADE_OFFERS[visit % TRADE_OFFERS.size()]


func planned_material(res: String) -> int:
	var total := 0
	for project in plans:
		total += int(defs[project.id].cost.get(res, 0))
	return total


func trade_blocker(visit: int, automatic: bool = false) -> String:
	if not caravan_present() or visit != caravan_visit() or visit == last_trade:
		return "TRADE_USED"
	if trained_count("merchant") == 0 or workers_at(market_cell) == 0:
		return "TRADE_NEED"
	var offer := caravan_offer(visit)
	var left := stock(offer.sell) - float(offer.amount)
	if left < 0:
		return "TRADE_LOW"
	var keep := protected_stock(offer.sell)
	if automatic:
		keep += planned_material(offer.sell)
	return "TRADE_FLOOR" if left < keep else ""


func trade(visit: int, automatic: bool = false) -> bool:
	if trade_blocker(visit, automatic) != "":
		return false
	var offer := caravan_offer(visit)
	last_trade = visit
	stocks[offer.sell] = stock(offer.sell) - float(offer.amount)
	stocks[offer.buy] = stock(offer.buy) + float(offer.receive)
	return true


## Continuous production and consumption over `dt_days` (can be a fraction).
func update(dt_days: float) -> void:
	if dt_days <= 0.0:
		return
	_advance_timers(dt_days)
	if bronze_study > 0.0 and study_blocker() == "":
		bronze_study = maxf(0.0, bronze_study - dt_days)
		if bronze_study <= 0.0000001:
			bronze_study = 0.0
			alert.emit("ANT_UNLOCK")
	_start_plans()
	_compute_staffing()
	var flow := _flow(dt_days, stocks, _staffing, true)
	_advance_training(dt_days, true, _staffing)
	rates = flow.net
	if bronze_study == 0.0 and first_ingot < 1.0:
		first_ingot += float(rates.get("bronze", 0.0)) * dt_days
		if first_ingot >= 0.99999999:
			first_ingot = 1.0
			alert.emit("ANT_ARRIVAL")
	_building_rates = flow.outputs
	_building_inputs = flow.inputs
	_waiting = flow.waiting
	household_used = flow.households
	unmet_needs = flow.unmet
	_short_food = _short_food or unmet_needs.has("food")
	_short_water = _short_water or unmet_needs.has("water")
	if caravan_present() and last_trade != caravan_visit():
		var visit := caravan_visit()
		if trade_auto.get(caravan_offer(visit).sell, false):
			trade(visit, true)


## A preview spends a scratch inventory and shadows only deposits it touches.
func forecast(cell: int, dt_days: float, season: int = -1, preview_field: int = -1, preview_open: bool = false) -> Dictionary:
	var staffing := _allocation(cell)
	var result := _flow(dt_days, stocks.duplicate(), staffing, false, season, preview_field, preview_open)
	result.staffing = staffing
	return result


func _flow(dt_days: float, inventory: Dictionary, staffing: Dictionary, apply: bool, season: int = -1, preview_field: int = -1, preview_open: bool = false) -> Dictionary:
	var wb := _wb()
	var consumed := {}
	var produced := {}
	var waiting := {}
	var households := {}
	var unmet := {}
	var deposits := {}
	var new_rates := {}
	for res in BASE_RESOURCES:
		new_rates[res] = 0.0
	if season < 0:
		season = season_index()
	var village_productivity := productivity()
	for cell in _building_cells:
		var def := def_of(cell)
		var produces: Dictionary = def.get("produces", {})
		if produces.is_empty() or not is_active(cell):
			continue
		var staffed_time := float(staffing.get(cell, 0.0)) * dt_days
		var mult: float = float(staffing.get(cell, 0.0)) * village_productivity
		if mult <= 0.0:
			continue
		if sowing.has(cell):
			var work := float(staffing[cell]) * dt_days
			var used := minf(float(sowing[cell]), work)
			mult *= maxf(0.0, 1.0 - used / work)
			staffed_time -= used
			if apply:
				sowing[cell] = float(sowing[cell]) - used
				if sowing[cell] < 0.0000001:
					sowing.erase(cell)
			if mult <= 0.0:
				continue
		if extra_plots.has(cell):
			mult *= 1.25
		mult *= 1.0 - 0.5 * minf(1.0, mentoring_days(cell) / dt_days)
		if def.has("seasons"):
			mult *= float(def.seasons[season])
		if bronze_equipment.has(planet.buildings[cell]):
			mult *= 1.25
		if def.get("fertility_bonus", false):
			mult *= 0.4 + planet.fertility[cell]
		if def.has("water_bonus") and near_water(cell):
			mult *= float(def.water_bonus)
		var order: Dictionary = orders.get(cell, {})
		if not order.is_empty():
			var output := str(order.res)
			var remaining := float(order.amount)
			if order.kind == "target":
				remaining -= float(inventory.get(output, 0.0))
			var unit_output := float(produces[output]) * dt_days * _perk_production(output)
			mult = minf(mult, maxf(0.0, remaining) / unit_output)
			if mult <= 0.00000001:
				continue
		var inputs := {}
		var opened: bool = preview_open if cell == preview_field else canals.has(cell) and canals[cell].open
		if opened:
			var requested := 2.0 * staffed_time
			var diverted := minf(requested, float(inventory.get("water", 0.0)))
			inventory.water = float(inventory.get("water", 0.0)) - diverted
			inputs.water = diverted / dt_days
			new_rates.water -= inputs.water
			mult *= 1.0 + IRRIGATION_BOOST[season] * diverted / requested
		if def.get("tool_bonus", false) and float(inventory.get("tools", 0.0)) > 0.0:
			mult *= float(wb.get("tool_bonus", 1.25))
			var worn := minf(float(inventory.get("tools", 0.0)), float(wb.get("tool_use_per_day", 0.05)) * dt_days)
			inventory["tools"] = float(inventory.get("tools", 0.0)) - worn
			inputs["tools"] = worn / dt_days
			new_rates["tools"] = float(new_rates["tools"]) - worn / dt_days

		# Inputs: the scarcest one limits the whole production.
		var consumes: Dictionary = def.get("consumes", {})
		var supply := 1.0
		var limiting := ""
		for res in consumes:
			var need := float(consumes[res]) * mult * dt_days
			var available := float(inventory.get(res, 0.0))
			if res == "grain":
				available = maxf(0.0, available - seed_target)
			if need > 0.0 and available / need < supply:
				supply = available / need
				limiting = str(res)
		if supply < 0.999 and not consumes.is_empty():
			waiting[cell] = limiting
		consumed[cell] = inputs
		if supply <= 0.0:
			continue
		for res in consumes:
			var used := float(consumes[res]) * mult * dt_days * supply
			inventory[res] = maxf(0.0, float(inventory.get(res, 0.0)) - used)
			inputs[res] = used / dt_days
			new_rates[res] = float(new_rates.get(res, 0.0)) - inputs[res]
		var outputs := {}
		for res in produces:
			var amount := float(produces[res]) * mult * dt_days * supply * _perk_production(str(res))
			if def.has("extracts"):
				amount = _extract(cell, str(def.extracts), amount, apply, deposits)
			inventory[res] = float(inventory.get(res, 0.0)) + amount
			if apply and order.get("kind", "") == "batch":
				order.amount = maxf(0.0, float(order.amount) - amount)
			outputs[res] = amount / dt_days
			new_rates[res] = float(new_rates.get(res, 0.0)) + outputs[res]
		produced[cell] = outputs

	for res in ["food", "water"]:
		var demand := population * float(settings.get(res + "_per_person_per_day", 1.0))
		var used := minf(float(inventory.get(res, 0.0)), demand * dt_days)
		households[res] = used / dt_days
		inventory[res] = maxf(0, float(inventory.get(res, 0.0)) - used)
		new_rates[res] -= used / dt_days
		if demand - used / dt_days > 0.00001:
			unmet[res] = demand - used / dt_days
	return {"outputs": produced, "inputs": consumed, "waiting": waiting, "households": households,
		"unmet": unmet, "net": new_rates}


## Once per in-game day: nature regrows, well-being evolves, population changes.
func daily_update() -> void:
	elapsed_days += 1
	if elapsed_days % (SEASON_DAYS * SEASONS.size()) == 0:
		sow_extra_plots()
	if not contract.is_empty() and elapsed_days > int(contract.due):
		contract.clear()
	if market_cell >= 0 and is_active(market_cell):
		market_days += 1
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
	_trim_trained()
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
		"townhall_level": townhall_level,
		"townhall_upgrade_left": snappedf(townhall_upgrade_left, 0.0001),
		"trained": trained,
		"training": training,
		"construction": _construction_to_save(),
		"preferred_cell": preferred_cell,
		"recipes": recipe_choices.duplicate(),
		"sowing": sowing.duplicate(),
		"canals": canals.duplicate(true),
		"bronze_study": bronze_study,
		"first_ingot": first_ingot,
		"advanced_chapter": advanced_chapter,
		"bronze_equipment": bronze_equipment.duplicate(),
		"market_days": market_days, "last_trade": last_trade,
		"pantry_days": pantry_days, "seed_target": seed_target, "extra_plots": extra_plots.duplicate(),
		"orders": orders.duplicate(true), "contract": contract.duplicate(), "contract_visit": contract_visit,
		"trade_reserves": trade_reserves.duplicate(), "trade_auto": trade_auto.duplicate(),
		"plans": plans.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	pantry_days = clampi(int(data.get("pantry_days", 0)), 0, 30)
	seed_target = clampi(int(data.get("seed_target", 0)), 0, 400)
	contract = data.get("contract", {}).duplicate()
	contract_visit = int(data.get("contract_visit", -1))
	orders.clear()
	extra_plots.clear()
	market_days = maxi(0, int(data.get("market_days", 0)))
	last_trade = clampi(int(data.get("last_trade", -1)), -1, caravan_visit())
	trade_reserves.clear()
	trade_auto.clear()
	for offer in TRADE_OFFERS:
		trade_reserves[offer.sell] = maxi(0, int(data.get("trade_reserves", {}).get(offer.sell, 0)))
		trade_auto[offer.sell] = bool(data.get("trade_auto", {}).get(offer.sell, false))
	bronze_study = clampf(float(data.get("bronze_study", -1.0)), -1.0, 2.0)
	first_ingot = clampf(float(data.get("first_ingot", 0.0)), 0.0, 1.0)
	advanced_chapter = clampi(int(data.get("advanced_chapter", 0)), 0, 3) if first_ingot >= 1.0 else 0
	bronze_equipment.clear()
	for sector in ["field", "quarry"]:
		if data.get("bronze_equipment", {}).get(sector, false):
			bronze_equipment[sector] = true
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
	trained = {}
	var saved_trained: Dictionary = data.get("trained", {})
	for p in saved_trained:
		trained[str(p)] = int(saved_trained[p])
	training = []
	for t in data.get("training", []):
		if typeof(t) == TYPE_DICTIONARY:
			var entry := {"profession": str(t.get("profession", "")), "left": float(t.get("left", 0.0))}
			if t.has("mentor"):
				entry["mentor"] = int(t.mentor)
			training.append(entry)
	construction = {}
	var saved_sites: Dictionary = data.get("construction", {})
	for key in saved_sites:
		var site: Dictionary = saved_sites[key]
		construction[int(key)] = {"left": float(site.get("left", 0.0)), "total": float(site.get("total", 1.0))}
	canals.clear()
	var saved_canals: Dictionary = data.get("canals", {})
	for key in saved_canals:
		var entry = saved_canals[key]
		if str(key).is_valid_int() and entry is Dictionary and valid_canal(int(key),int(entry.get("source",-1))):
			canals[int(key)] = {"source": int(entry.source), "open": bool(entry.get("open",false))}
	recipe_choices.clear()
	var saved_recipes: Dictionary = data.get("recipes", {})
	for key in saved_recipes:
		if str(key).is_valid_int():
			select_recipe(int(key), str(saved_recipes[key]))
	sowing.clear()
	var saved_sowing: Dictionary = data.get("sowing", {})
	for key in saved_sowing:
		var cell := int(key)
		if cell >= 0 and cell < planet.cell_count() and planet.buildings[cell] == "field":
			var left := clampf(float(saved_sowing[key]), 0.0, 0.5)
			if left > 0.0:
				sowing[cell] = left
	preferred_cell = int(data.get("preferred_cell", -1))
	if preferred_cell < 0 or preferred_cell >= planet.cell_count() or planet.buildings[preferred_cell] == "":
		preferred_cell = -1
	plans.clear()
	for entry in data.get("plans", []):
		if entry is Dictionary and defs.has(entry.get("id", "")) and plans.size() < 2:
			var cell := int(entry.get("cell", -1))
			if cell >= 0 and cell < planet.cell_count():
				plans.append({"id": str(entry.id), "cell": cell})
	if data.has("townhall_level"):
		townhall_level = clampi(int(data.townhall_level), 1, max_level())
		townhall_upgrade_left = float(data.get("townhall_upgrade_left", -1.0))
		_rebuild_caches()
	else:
		_migrate_to_townhall()

	for key in data.get("orders", {}):
		var cell := int(key)
		var order: Dictionary = data.orders[key]
		if cell in _building_cells and def_of(cell).get("produces", {}).has(order.get("res", "")) and order.get("kind", "") in ["target", "batch"]:
			orders[cell] = order.duplicate()
	for key in data.get("extra_plots", {}):
		var cell := int(key)
		if cell in _building_cells and building_at(cell) == "field":
			extra_plots[cell] = true


# --- Internals ---------------------------------------------------------------

func _wb() -> Dictionary:
	return settings.get("wellbeing", {})


## Sum of a village bonus ("happiness", "health", "growth_bonus") from
## buildings, scaled by how well each one is staffed.
func _sum_bonus(key: String) -> float:
	var total := 0.0
	for cell in _building_cells:
		if not is_active(cell):
			continue
		var value := float(def_of(cell).get(key, 0.0))
		if value != 0.0:
			total += value * float(_staffing.get(cell, 1.0 if int(def_of(cell).get("workers", 0)) == 0 else 0.0))
	return total


func _pay(cost: Dictionary) -> void:
	for res in cost:
		stocks[res] = stock(res) - float(cost[res])


func _start_site(cell: int, days: float) -> void:
	if days > 0.0 and not townhall_levels.is_empty():
		construction[cell] = {"left": days, "total": days}


func _build_speed() -> float:
	var speed := 1.0
	for perk in perks():
		speed *= float(perk.get("build_speed", 1.0))
	return speed


func _train_speed() -> float:
	var speed := 1.0
	for perk in perks():
		speed *= float(perk.get("training_speed", 1.0))
	return speed


func _perk_production(res: String) -> float:
	var mult := 1.0
	for perk in perks():
		mult *= float(perk.get("production", {}).get(res, 1.0))
	return mult


## Construction sites, town hall upgrade and trainings move forward.
func _advance_timers(dt_days: float) -> void:
	var build_step := dt_days * _build_speed()
	var finished: Array = []
	for cell in construction:
		construction[cell].left = float(construction[cell].left) - build_step
		if float(construction[cell].left) <= 0.0:
			finished.append(cell)
	for cell in finished:
		construction.erase(cell)
	if not finished.is_empty():
		_rebuild_caches()
		for cell in finished:
			construction_done.emit(cell)
		changed.emit()
	if townhall_upgrade_left >= 0.0:
		townhall_upgrade_left -= build_step
		if townhall_upgrade_left <= 0.0:
			townhall_upgrade_left = -1.0
			townhall_level = mini(townhall_level + 1, max_level())
			_rebuild_caches()
			level_up.emit(townhall_level)
			changed.emit()
	_advance_training(dt_days, false, {})


func _advance_training(dt_days: float, apprentices: bool, staffing: Dictionary) -> void:
	var train_step := dt_days * _train_speed()
	var done: Array = []
	for t in training:
		if apprentices != t.has("mentor"):
			continue
		if apprentices and float(staffing.get(int(t.mentor), 0)) <= 0:
			continue
		t.left = float(t.left) - train_step
		if float(t.left) <= 0.0:
			done.append(t)
	for t in done:
		training.erase(t)
		trained[t.profession] = trained_count(str(t.profession)) + 1
		training_done.emit(str(t.profession))


## When people leave or die, trainings stop first, then jobs are lost
## (from the largest profession).
func _trim_trained() -> void:
	while population < trained_total() + training.size():
		if not training.is_empty():
			training.pop_back()
			continue
		var biggest := ""
		for p in trained:
			if biggest == "" or int(trained[p]) > int(trained[biggest]):
				biggest = p
		if biggest == "" or int(trained[biggest]) <= 0:
			break
		trained[biggest] = int(trained[biggest]) - 1


func _construction_to_save() -> Dictionary:
	var out := {}
	for cell in construction:
		out[str(cell)] = {"left": snappedf(float(construction[cell].left), 0.0001), "total": construction[cell].total}
	return out


## Saves from before the town hall: the central campfire becomes the town
## hall (level 1) and the people already working are trained for their job,
## so the village keeps running exactly as before.
func _migrate_to_townhall() -> void:
	townhall_level = 1
	townhall_upgrade_left = -1.0
	if village_center >= 0 and planet.buildings[village_center] == "campfire" and defs.has("townhall"):
		planet.buildings[village_center] = "townhall"
	_rebuild_caches()
	if townhall_levels.is_empty():
		return
	var free := population
	for cell in _building_cells:
		var def := def_of(cell)
		var profession := str(def.get("profession", ""))
		var need := int(def.get("workers", 0))
		if profession == "" or need <= 0:
			continue
		var got := mini(need, free)
		free -= got
		trained[profession] = trained_count(profession) + got
	_compute_staffing()


func _place(cell: int, id: String) -> void:
	recipe_choices.erase(cell)
	sowing.erase(cell)
	planet.buildings[cell] = id
	_rebuild_caches()
	changed.emit()


func _rebuild_caches() -> void:
	_building_cells.clear()
	market_cell = -1
	if planet == null:
		return
	for i in planet.cell_count():
		if planet.buildings[i] != "":
			_building_cells.append(i)
			if planet.buildings[i] == "market":
				market_cell = i
	_building_cells.sort_custom(func(a, b):
		var pa := int(def_of(a).get("priority", 9))
		var pb := int(def_of(b).get("priority", 9))
		return pa < pb or (pa == pb and a < b))
	_territory = {}
	for cell in _building_cells:
		var radius := int(def_of(cell).get("territory", 2))
		if cell == village_center:
			radius = int(level_def().get("territory", radius))
		_mark_territory(cell, radius * territory_scale)
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


## Gives jobs to trained villagers, building by building (priority order).
## A building only gets villagers trained for its profession. Without
## progression data (old saves/tests), anyone can work anywhere.
func _compute_staffing() -> void:
	_staffing = _allocation(preferred_cell)


func _allocation(priority: int) -> Dictionary:
	var allocation := {}
	var free := population
	var pools := trained.duplicate()
	var order := _building_cells
	if priority in _building_cells:
		order = _building_cells.duplicate()
		order.erase(priority)
		order.push_front(priority)
	for cell in order:
		var def := def_of(cell)
		var need := int(def.get("workers", 0))
		if not is_active(cell):
			allocation[cell] = 0.0
			continue
		if need <= 0:
			allocation[cell] = 1.0
			continue
		var got := 0
		var profession := str(def.get("profession", ""))
		if townhall_levels.is_empty() or profession == "":
			got = mini(need, free)
		else:
			got = mini(free, mini(need, int(pools.get(profession, 0))))
			pools[profession] = int(pools.get(profession, 0)) - got
		free -= got
		allocation[cell] = float(got) / float(need)
	return allocation


func _cell_and_neighbors(cell: int) -> Array:
	var cells: Array = [cell]
	cells.append_array(Array(planet.grid.neighbors[cell]))
	return cells


## Takes up to `wanted` of `res` from the cell, then its neighbours.
## Returns the amount actually taken (deposits run out).
func _extract(cell: int, res: String, wanted: float, apply: bool, deposits: Dictionary) -> float:
	var remaining := wanted
	for c in _cell_and_neighbors(cell):
		if remaining <= 0.0:
			break
		var deposit: Dictionary = planet.resources[c]
		if not apply:
			if not deposits.has(c):
				deposits[c] = deposit.duplicate()
			deposit = deposits[c]
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
