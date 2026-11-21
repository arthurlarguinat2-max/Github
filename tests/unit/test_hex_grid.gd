extends "res://tests/test_case.gd"

const HexGrid := preload("res://scripts/simulation/hex_grid.gd")


func test_cell_count_matches_formula() -> void:
	for f in [1, 2, 6, 8]:
		var grid := HexGrid.new(f)
		assert_eq(grid.cell_count(), HexGrid.cell_count_for(f), "frequency %d" % f)
	assert_eq(HexGrid.cell_count_for(6), 362)


func test_exactly_twelve_pentagons() -> void:
	var grid := HexGrid.new(6)
	var pentagons := 0
	var hexagons := 0
	for i in grid.cell_count():
		match grid.neighbors[i].size():
			5: pentagons += 1
			6: hexagons += 1
	assert_eq(pentagons, 12)
	assert_eq(hexagons, grid.cell_count() - 12)


func test_neighbors_are_symmetric() -> void:
	var grid := HexGrid.new(6)
	for i in grid.cell_count():
		for nb in grid.neighbors[i]:
			assert_true(i in grid.neighbors[nb], "%d <-> %d" % [i, nb])


func test_corners_match_neighbors() -> void:
	var grid := HexGrid.new(6)
	for i in grid.cell_count():
		assert_eq(grid.corners[i].size(), grid.neighbors[i].size(), "cell %d" % i)


func test_centers_are_unit_vectors() -> void:
	var grid := HexGrid.new(6)
	for c in grid.centers:
		assert_almost_eq(c.length(), 1.0, 1e-4)


func test_find_cell_returns_own_cell() -> void:
	var grid := HexGrid.new(6)
	for i in grid.cell_count():
		assert_eq(grid.find_cell(grid.centers[i] * 1.05), i)


func test_corners_are_counter_clockwise() -> void:
	# Seen from outside, consecutive corners turn around the outward normal.
	var grid := HexGrid.new(6)
	for i in [0, 17, 100, 361]:
		var c: Vector3 = grid.centers[i]
		var cs: PackedVector3Array = grid.corners[i]
		for k in cs.size():
			var turn := (cs[k] - c).cross(cs[(k + 1) % cs.size()] - c).dot(c)
			assert_true(turn > 0.0, "cell %d corner %d" % [i, k])
