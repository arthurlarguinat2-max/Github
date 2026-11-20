extends "res://tests/test_case.gd"

const Simulation := preload("res://scripts/simulation/simulation.gd")

const CONFIG := {"ticks_per_day": 100, "allowed_speeds": [0, 1, 2, 4]}


func test_starts_on_day_one() -> void:
	var sim := Simulation.new(42, CONFIG)
	assert_eq(sim.day(), 1)
	assert_almost_eq(sim.time_of_day(), 0.0)


func test_days_advance_with_ticks() -> void:
	var sim := Simulation.new(42, CONFIG)
	sim.run_ticks(250)
	assert_eq(sim.day(), 3)
	assert_almost_eq(sim.time_of_day(), 0.5)


func test_day_passed_signal() -> void:
	var sim := Simulation.new(42, CONFIG)
	var days: Array = []
	sim.day_passed.connect(func(d): days.append(d))
	sim.run_ticks(300)
	assert_eq(days, [2, 3, 4])


func test_only_allowed_speeds() -> void:
	var sim := Simulation.new(42, CONFIG)
	assert_true(sim.set_speed(4))
	assert_false(sim.set_speed(3))
	assert_eq(sim.speed, 4)


func test_save_roundtrip_is_deterministic() -> void:
	var a := Simulation.new(1234, CONFIG)
	a.run_ticks(77)
	a.rng.randi()  # Advance the RNG so its state matters.
	var json := JSON.stringify(a.to_dict())
	var b := Simulation.new(0, CONFIG)
	b.from_dict(JSON.parse_string(json))
	assert_eq(b.tick, 77)
	assert_eq(b.world_seed, 1234)
	assert_eq(b.rng.randi(), a.rng.randi(), "RNG must continue identically")


func test_offline_progress_is_capped() -> void:
	var sim := Simulation.new(1, CONFIG)
	# 100 hours away, cap 8 h, efficiency 0.5, 10 ticks/s -> 8*3600*0.5*10 ticks.
	var ticks := sim.advance_offline(100 * 3600.0, 10.0, 8 * 3600.0, 0.5)
	assert_eq(ticks, 144000)
	assert_eq(sim.tick, 144000)


func test_invalid_saved_speed_falls_back() -> void:
	var sim := Simulation.new(1, CONFIG)
	sim.from_dict({"world_seed": 1, "tick": 5, "speed": 99})
	assert_eq(sim.speed, 1)
