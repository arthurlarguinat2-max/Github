## Procedural planet generation from a seed: terrain, fertility, resources.
## Pure and deterministic (same seed + same data = same planet).
## All tuning lives in data/game_config.json ("planet") and data/terrains.json.
extends RefCounted


## Returns { "terrain": PackedStringArray, "fertility": PackedFloat32Array,
##           "resources": Array[Dictionary] } for every cell of `grid`.
static func generate(grid, world_seed: int, terrains: Dictionary, settings: Dictionary) -> Dictionary:
	var n: int = grid.cell_count()
	var elevation_noise := _noise(world_seed, float(settings.get("noise_frequency", 1.3)), 4)
	var moisture_noise := _noise(world_seed + 101, float(settings.get("moisture_frequency", 1.7)), 3)

	var elevation := PackedFloat32Array()
	var moisture := PackedFloat32Array()
	elevation.resize(n)
	moisture.resize(n)
	for i in n:
		var p: Vector3 = grid.centers[i]
		elevation[i] = elevation_noise.get_noise_3dv(p)
		moisture[i] = clampf(moisture_noise.get_noise_3dv(p) * 0.5 + 0.5, 0.0, 1.0)

	# Sea level chosen so that the ocean covers a fixed share of the planet,
	# whatever the seed: every planet stays playable.
	var sorted := elevation.duplicate()
	sorted.sort()
	var ocean_fraction := clampf(float(settings.get("ocean_fraction", 0.55)), 0.0, 0.95)
	var sea := sorted[int(ocean_fraction * float(n - 1))]
	var low := sorted[0]
	var high := sorted[n - 1]
	var shallow_line := sea - (sea - low) * float(settings.get("shallow_band", 0.12)) * 3.0

	var terrain := PackedStringArray()
	terrain.resize(n)
	for i in n:
		var latitude := absf(grid.centers[i].y)
		var e := elevation[i]
		if e < sea:
			if latitude > float(settings.get("ice_latitude_water", 0.9)):
				terrain[i] = "ice"
			elif e > shallow_line:
				terrain[i] = "shallow"
			else:
				terrain[i] = "ocean"
			continue
		if latitude > float(settings.get("ice_latitude_land", 0.8)):
			terrain[i] = "ice"
			continue
		var h := (e - sea) / maxf(high - sea, 0.0001)  # 0 at the shore, 1 at the highest peak
		if h > float(settings.get("mountain_threshold", 0.7)):
			terrain[i] = "mountain"
		elif h > float(settings.get("hills_threshold", 0.48)):
			terrain[i] = "hills"
		else:
			var temperature := 1.0 - latitude * 1.1 - h * 0.3
			if temperature > 0.62 and moisture[i] < 0.4:
				terrain[i] = "desert"
			elif moisture[i] > 0.55:
				terrain[i] = "forest"
			else:
				terrain[i] = "plains"

	# Beaches: low land touching water (second pass: needs the water map).
	var beach_threshold := float(settings.get("beach_threshold", 0.1))
	for i in n:
		if terrain[i] in ["plains", "forest", "desert"]:
			var h := (elevation[i] - sea) / maxf(high - sea, 0.0001)
			if h < beach_threshold and _touches_water(grid, terrain, i, terrains):
				terrain[i] = "beach"

	# Fertility and resources.
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 7
	var fertility := PackedFloat32Array()
	fertility.resize(n)
	var resources: Array[Dictionary] = []
	for i in n:
		var def: Dictionary = terrains.get(terrain[i], {})
		var base := float(def.get("fertility", 0.0))
		fertility[i] = snappedf(clampf(base * (0.75 + 0.5 * moisture[i]), 0.0, 1.0), 0.01)
		var cell_resources := {}
		var table: Dictionary = def.get("resources", {})
		for res_id in table:
			var spec: Array = table[res_id]
			if rng.randf() < float(spec[0]):
				cell_resources[res_id] = rng.randi_range(int(spec[1]), int(spec[2]))
		resources.append(cell_resources)
	return {"terrain": terrain, "fertility": fertility, "resources": resources}


static func _touches_water(grid, terrain: PackedStringArray, cell: int, terrains: Dictionary) -> bool:
	for nb in grid.neighbors[cell]:
		var def: Dictionary = terrains.get(terrain[nb], {})
		if def.get("water", terrain[nb] in ["ocean", "shallow"]):
			return true
	return false


static func _noise(noise_seed: int, frequency: float, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	return noise
