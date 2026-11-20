## Core game simulation: pure, deterministic, frame-rate independent.
##
## Never touches nodes, rendering or the file system. The rendering layer
## reads its state; the GameState autoload drives it with fixed ticks.
## Everything that must survive a restart goes through to_dict()/from_dict().
extends RefCounted

signal day_passed(day: int)

const DEFAULT_TICKS_PER_DAY := 600

var world_seed: int = 0
var tick: int = 0
var speed: int = 1
var ticks_per_day: int = DEFAULT_TICKS_PER_DAY
var allowed_speeds: Array = [0, 1, 2, 4]

## Deterministic random generator owned by the simulation (seeded from world_seed).
var rng := RandomNumberGenerator.new()


func _init(p_seed: int = 0, config: Dictionary = {}) -> void:
	world_seed = p_seed
	rng.seed = p_seed
	ticks_per_day = maxi(int(config.get("ticks_per_day", DEFAULT_TICKS_PER_DAY)), 1)
	allowed_speeds = config.get("allowed_speeds", allowed_speeds)


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
	# Future phases plug their systems here (production, population, pollution...).
	if day() != previous_day:
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
	# Phase 0: a plain fast-forward. Later phases will use an aggregated model
	# (daily averages) instead of stepping every tick.
	run_ticks(ticks)
	return ticks


func to_dict() -> Dictionary:
	return {
		"world_seed": world_seed,
		"tick": tick,
		"speed": speed,
		"rng_state": str(rng.state),  # stored as string: JSON numbers are doubles.
	}


func from_dict(data: Dictionary) -> void:
	world_seed = int(data.get("world_seed", world_seed))
	tick = maxi(int(data.get("tick", 0)), 0)
	var saved_speed := int(data.get("speed", 1))
	speed = saved_speed if saved_speed in allowed_speeds else 1
	rng.seed = world_seed
	if data.has("rng_state"):
		rng.state = str(data["rng_state"]).to_int()
