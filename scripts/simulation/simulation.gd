## Core game simulation: pure, deterministic, frame-rate independent.
##
## Never touches nodes, rendering or the file system. The rendering layer
## reads its state; the GameState autoload drives it with fixed ticks.
## Everything that must survive a restart goes through to_dict()/from_dict().
extends RefCounted

signal day_passed(day: int)

const PlanetState := preload("res://scripts/simulation/planet_state.gd")
const Economy := preload("res://scripts/simulation/economy.gd")
const DEFAULT_TICKS_PER_DAY := 600

var world_seed: int = 0
var tick: int = 0
var speed: int = 1
var ticks_per_day: int = DEFAULT_TICKS_PER_DAY
var allowed_speeds: Array = [0, 1, 2, 4]

## Deterministic random generator owned by the simulation (seeded from world_seed).
var rng := RandomNumberGenerator.new()
## Every cell of the planet (terrain, resources...).
var planet: PlanetState
var terrain_defs: Dictionary = {}
var planet_settings: Dictionary = {}
## Stocks, buildings, workers, population.
var economy := Economy.new()
var building_defs: Dictionary = {}
var start_settings: Dictionary = {}
var economy_settings: Dictionary = {}


func _init(p_seed: int = 0, config: Dictionary = {}) -> void:
	world_seed = p_seed
	rng.seed = p_seed
	ticks_per_day = maxi(int(config.get("ticks_per_day", DEFAULT_TICKS_PER_DAY)), 1)
	allowed_speeds = config.get("allowed_speeds", allowed_speeds)
	terrain_defs = config.get("terrains", {})
	planet_settings = config.get("planet", {})
	building_defs = config.get("buildings", {})
	start_settings = config.get("start", {})
	economy_settings = config.get("economy", {})
	planet = PlanetState.new(int(planet_settings.get("frequency", 6)))
	planet.generate(world_seed, terrain_defs, planet_settings)
	economy.setup(planet, building_defs, terrain_defs, economy_settings)
	economy.found_village(start_settings)


## Current in-game day, starting at 1.
func day() -> int:
	return tick / ticks_per_day + 1


## Position inside the current day, 0.0 (dawn) .. 1.0. Drives the day/night cycle.
func time_of_day() -> float:
	return float(tick % ticks_per_day) / float(ticks_per_day)


## Advances the world by exactly one fixed tick.
func step() -> void:
	var previous_day := day()
	tick += 1
	economy.update(1.0 / float(ticks_per_day))
	if day() != previous_day:
		economy.daily_update()
		day_passed.emit(day())


func run_ticks(count: int) -> void:
	for i in count:
		step()


func set_speed(value: int) -> bool:
	if value in allowed_speeds:
		speed = value
		return true
	return false


## Simplified catch-up for time spent away from the game.
## `seconds` is real time; `tick_rate_hz` converts it to ticks;
## `efficiency` (0..1) makes offline time worth less than active play.
## Returns the number of ticks simulated.
func advance_offline(seconds: float, tick_rate_hz: float, cap_seconds: float, efficiency: float) -> int:
	var effective := clampf(seconds, 0.0, cap_seconds) * clampf(efficiency, 0.0, 1.0)
	var ticks := int(effective * tick_rate_hz)
	# Big steps (1/20 of a day) instead of every tick: same rules, much faster.
	var chunk := maxi(1, ticks_per_day / 20)
	var remaining := ticks
	while remaining > 0:
		var n := mini(chunk, remaining)
		var previous_day := day()
		tick += n
		economy.update(float(n) / float(ticks_per_day))
		for d in day() - previous_day:
			economy.daily_update()
		remaining -= n
	return ticks


func to_dict() -> Dictionary:
	return {
		"world_seed": world_seed,
		"tick": tick,
		"speed": speed,
		"rng_state": str(rng.state),  # stored as string: JSON numbers are doubles.
		"planet": planet.to_dict(),
		"economy": economy.to_dict(),
	}


func from_dict(data: Dictionary) -> void:
	world_seed = int(data.get("world_seed", world_seed))
	tick = maxi(int(data.get("tick", 0)), 0)
	var saved_speed := int(data.get("speed", 1))
	speed = saved_speed if saved_speed in allowed_speeds else 1
	rng.seed = world_seed
	if data.has("rng_state"):
		rng.state = str(data["rng_state"]).to_int()
	# Saves made before Phase 1 have no planet: generate it from the seed.
	var loaded := false
	if typeof(data.get("planet")) == TYPE_DICTIONARY:
		loaded = planet.from_dict(data["planet"])
	if not loaded:
		planet = PlanetState.new(int(planet_settings.get("frequency", 6)))
		planet.generate(world_seed, terrain_defs, planet_settings)
	economy = Economy.new()
	economy.setup(planet, building_defs, terrain_defs, economy_settings)
	if typeof(data.get("economy")) == TYPE_DICTIONARY:
		economy.from_dict(data["economy"])
	else:
		# Saves made before Phase 2: found the village now.
		economy.found_village(start_settings)
