## Converts variable frame time into a whole number of fixed simulation ticks.
##
## Pure logic (no Node, no engine singletons) so it can be unit-tested headless.
## The accumulator keeps the leftover time between frames, which makes the
## simulation independent from the frame rate. A per-frame cap prevents the
## "spiral of death" when a frame takes too long (e.g. app resumed from background).
extends RefCounted

var tick_rate_hz: float = 10.0
var max_ticks_per_frame: int = 40
var _accumulator: float = 0.0


func _init(p_tick_rate_hz: float = 10.0, p_max_ticks_per_frame: int = 40) -> void:
	tick_rate_hz = maxf(p_tick_rate_hz, 0.001)
	max_ticks_per_frame = maxi(p_max_ticks_per_frame, 1)


## Duration of one tick in seconds.
func tick_duration() -> float:
	return 1.0 / tick_rate_hz


## Feeds `delta` real seconds at the given speed multiplier and returns how
## many ticks must be simulated now. Speed 0 means paused.
func advance(delta: float, speed: int) -> int:
	if speed <= 0 or delta <= 0.0:
		return 0
	_accumulator += delta * speed
	var dt := tick_duration()
	var ticks := int(floor(_accumulator / dt))
	if ticks > max_ticks_per_frame:
		# Drop the excess instead of trying to catch up forever.
		ticks = max_ticks_per_frame
		_accumulator = 0.0
	else:
		_accumulator -= ticks * dt
	return ticks


## Fraction (0..1) of the next tick already elapsed: useful for smooth rendering.
func interpolation_alpha() -> float:
	return clampf(_accumulator / tick_duration(), 0.0, 1.0)


func reset() -> void:
	_accumulator = 0.0
