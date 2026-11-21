## State of every cell of the planet: terrain, fertility, resources, pollution.
## The hex grid geometry is rebuilt from `frequency`; the cell data itself is
## saved, so a planet never changes when the generator is tuned later.
extends RefCounted

const HexGrid := preload("res://scripts/simulation/hex_grid.gd")
const PlanetGenerator := preload("res://scripts/simulation/planet_generator.gd")

var grid: HexGrid
var terrain := PackedStringArray()
var fertility := PackedFloat32Array()
## One Dictionary per cell: resource id -> remaining amount.
var resources: Array[Dictionary] = []
var pollution := PackedFloat32Array()
## Building id on each cell ("" = none).
var buildings := PackedStringArray()


func _init(frequency: int = 6) -> void:
	grid = HexGrid.new(frequency)


func cell_count() -> int:
	return grid.cell_count()


func generate(world_seed: int, terrains: Dictionary, settings: Dictionary) -> void:
	var data := PlanetGenerator.generate(grid, world_seed, terrains, settings)
	terrain = data.terrain
	fertility = data.fertility
	resources = data.resources
	pollution = PackedFloat32Array()
	pollution.resize(cell_count())
	pollution.fill(0.0)
	buildings = PackedStringArray()
	buildings.resize(cell_count())


func count_terrain(terrain_id: String) -> int:
	return terrain.count(terrain_id)


func to_dict() -> Dictionary:
	return {
		"frequency": grid.frequency,
		"terrain": Array(terrain),
		"fertility": Array(fertility),
		"resources": resources,
		"pollution": Array(pollution),
		"buildings": Array(buildings),
	}


## Loads saved cells. Returns false if the data is unusable (caller regenerates).
func from_dict(data: Dictionary) -> bool:
	var frequency := int(data.get("frequency", grid.frequency))
	if frequency != grid.frequency:
		grid = HexGrid.new(frequency)
	var n := cell_count()
	var saved_terrain: Array = data.get("terrain", [])
	var saved_fertility: Array = data.get("fertility", [])
	var saved_resources: Array = data.get("resources", [])
	if saved_terrain.size() != n or saved_fertility.size() != n or saved_resources.size() != n:
		return false
	terrain = PackedStringArray(saved_terrain)
	fertility = PackedFloat32Array(saved_fertility)
	resources.clear()
	for r in saved_resources:
		var cell := {}
		if typeof(r) == TYPE_DICTIONARY:
			for key in r:
				cell[str(key)] = snappedf(float(r[key]), 0.01)
		resources.append(cell)
	var saved_pollution: Array = data.get("pollution", [])
	pollution = PackedFloat32Array(saved_pollution) if saved_pollution.size() == n else PackedFloat32Array()
	if pollution.size() != n:
		pollution.resize(n)
		pollution.fill(0.0)
	var saved_buildings: Array = data.get("buildings", [])
	buildings = PackedStringArray(saved_buildings) if saved_buildings.size() == n else PackedStringArray()
	buildings.resize(n)
	return true
