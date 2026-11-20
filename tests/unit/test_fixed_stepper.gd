extends "res://tests/test_case.gd"

const FixedStepper := preload("res://scripts/simulation/fixed_stepper.gd")


func test_paused_produces_no_ticks() -> void:
	var s := FixedStepper.new(10.0, 40)
	assert_eq(s.advance(1.0, 0), 0)


func test_accumulates_partial_frames() -> void:
	var s := FixedStepper.new(10.0, 40)
	assert_eq(s.advance(0.05, 1), 0)
	assert_eq(s.advance(0.05, 1), 1)
	assert_almost_eq(s.interpolation_alpha(), 0.0, 1e-4)


func test_speed_multiplies_ticks() -> void:
	var s := FixedStepper.new(10.0, 40)
	assert_eq(s.advance(1.0, 4), 40)


func test_frame_rate_independent() -> void:
	# 1 second at 60 FPS and at 30 FPS must give the same number of ticks.
	var a := FixedStepper.new(10.0, 40)
	var b := FixedStepper.new(10.0, 40)
	var ta := 0
	var tb := 0
	for i in 60:
		ta += a.advance(1.0 / 60.0, 1)
	for i in 30:
		tb += b.advance(1.0 / 30.0, 1)
	assert_true(absi(ta - tb) <= 1, "60fps=%d 30fps=%d" % [ta, tb])
	assert_true(ta >= 9 and ta <= 10)


func test_long_frame_is_capped() -> void:
	var s := FixedStepper.new(10.0, 40)
	assert_eq(s.advance(3600.0, 1), 40)
	assert_eq(s.advance(0.0, 1), 0, "excess time must be dropped")
