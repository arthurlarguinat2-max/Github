## Organic terrain: a smooth, rolling surface instead of hexagonal prisms.
##
## Each cell gives a target height and color; the surface blends them with
## the neighbouring cells (soft hills, natural coastlines, color gradients),
## adds rounded mountain peaks and a little noise. Water cells sit below sea
## level so a separate animated sea sphere draws the coast automatically.
## The hex grid stays visible as thin outlines (gameplay readability).
extends RefCounted

const SEA_LEVEL := 1.0
const DEEP_FLOOR := 0.962
const SHALLOW_FLOOR := 0.986
const LAND_LIFT := 1.004       # Land sits a little above the sea.
const NOISE_AMPLITUDE := 0.0035

var planet
var terrain_defs: Dictionary = {}
var palette: Dictionary = {}
var world_seed := 0
## Average angle between neighbouring cell centers (blend radius).
var spacing := 0.1

var _heights := PackedFloat32Array()
var _colors := PackedColorArray()
var _peaks := PackedFloat32Array()
var _peak_colors := PackedColorArray()
var _noise := FastNoiseLite.new()
var _last_cell := 0


func setup(p_planet, p_terrain_defs: Dictionary, p_palette: Dictionary, p_seed: int) -> void:
	planet = p_planet
	terrain_defs = p_terrain_defs
	palette = p_palette
	world_seed = p_seed
	_noise.seed = p_seed + 77
	_noise.frequency = 2.6
	_noise.fractal_octaves = 3
	var grid = planet.grid
	var total := 0.0
	var count := 0
	for i in mini(60, grid.cell_count()):
		for nb in grid.neighbors[i]:
			total += grid.centers[i].angle_to(grid.centers[nb])
			count += 1
	spacing = total / maxf(count, 1)
	var n: int = planet.cell_count()
	_heights.resize(n)
	_colors.resize(n)
	_peaks.resize(n)
	_peak_colors.resize(n)
	for i in n:
		var id: String = planet.terrain[i]
		var def: Dictionary = terrain_defs.get(id, {})
		var color := Color(str(palette.get(id, def.get("color", "ff00ff"))))
		# Gentle per-cell variation so the land never looks flat-painted.
		var tint := float(posmod(hash(i * 7919 + p_seed), 100)) / 100.0
		color = color.darkened(tint * 0.06).lightened((1.0 - tint) * 0.03)
		if def.get("water", false):
			_heights[i] = DEEP_FLOOR if id == "ocean" else SHALLOW_FLOOR
			# Seabed: sand under shallow water, dark blue in the deep.
			color = Color("cfe9d8").lerp(color, 0.7) if id == "shallow" else color.darkened(0.3)
		else:
			_heights[i] = LAND_LIFT + float(def.get("height", 0.0))
		_colors[i] = color
		# Peaks scale with the cell size: soft round mountains on any planet size.
		_peaks[i] = float(def.get("peak", 0.0)) * clampf(spacing / 0.12, 0.35, 1.3)
		_peak_colors[i] = Color(str(def.get("peak_color", color.to_html(false))))


## Nearest cell to `dir`, found by walking from a nearby cell (fast).
func cell_of(dir: Vector3, hint: int = -1) -> int:
	var grid = planet.grid
	var c := hint if hint >= 0 else _last_cell
	var best_dot: float = grid.centers[c].dot(dir)
	while true:
		var best := c
		for nb in grid.neighbors[c]:
			var d: float = grid.centers[nb].dot(dir)
			if d > best_dot:
				best_dot = d
				best = nb
		if best == c:
			break
		c = best
	_last_cell = c
	return c


## Surface radius and color at direction `dir` (unit vector).
func sample(dir: Vector3, hint: int = -1) -> Array:
	var grid = planet.grid
	var c := cell_of(dir, hint)
	var reach := spacing * 1.15
	var total := 0.0
	var h := 0.0
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var cells: Array = [c]
	cells.append_array(Array(grid.neighbors[c]))
	for k in cells:
		var w := maxf(0.0, 1.0 - dir.angle_to(grid.centers[k]) / reach)
		w = w * w * (3.0 - 2.0 * w)  # Smoothstep: soft, rounded blends.
		if k == c:
			w = maxf(w, 0.05)
		total += w
		h += _heights[k] * w
		var col: Color = _colors[k]
		r += col.r * w
		g += col.g * w
		b += col.b * w
	h /= total
	var color := Color(r / total, g / total, b / total)
	var weathering := _noise.get_noise_3dv(dir * 6.0)
	if _peaks[c] > 0.0:
		var d := clampf(1.0 - dir.angle_to(grid.centers[c]) / (spacing * 0.68), 0.0, 1.0)
		var ridge := 1.0 - absf(_noise.get_noise_3dv(dir * 12.0))
		var summit := d * d * (2.0 - d) * (0.68 + 0.72 * ridge)
		h += _peaks[c] * summit
		color = color.lerp(_peak_colors[c], smoothstep(0.4, 0.95, summit + weathering * 0.22))
	if h > SEA_LEVEL:
		h += weathering * NOISE_AMPLITUDE
	return [h, color, c]


func surface_radius(dir: Vector3, hint: int = -1) -> float:
	return sample(dir, hint)[0]


## Height where buildings stand (center of the cell, never under water).
func cell_top(cell: int) -> float:
	return maxf(surface_radius(planet.grid.centers[cell], cell), SEA_LEVEL + 0.002)


## Smooth land mesh from a subdivided icosphere (normals averaged per vertex).
func build_land_mesh(subdivisions: int) -> ArrayMesh:
	var sphere := _icosphere(subdivisions)
	var dirs: PackedVector3Array = sphere[0]
	var faces: PackedInt32Array = sphere[1]
	var positions := PackedVector3Array()
	var colors := PackedColorArray()
	positions.resize(dirs.size())
	colors.resize(dirs.size())
	var hint := 0
	for i in dirs.size():
		var s := sample(dirs[i], hint)
		positions[i] = dirs[i] * float(s[0])
		colors[i] = s[1]
		hint = s[2]
	# Faces: make them face outward (Godot front faces are clockwise).
	var normals := PackedVector3Array()
	normals.resize(dirs.size())
	for f in range(0, faces.size(), 3):
		var a := faces[f]
		var b := faces[f + 1]
		var c := faces[f + 2]
		var n := (positions[b] - positions[a]).cross(positions[c] - positions[a])
		if n.dot(positions[a]) > 0.0:
			faces[f + 1] = c
			faces[f + 2] = b
		else:
			n = -n
		normals[a] += n
		normals[b] += n
		normals[c] += n
	for i in normals.size():
		normals[i] = normals[i].normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = faces
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/terrain/ground.gdshader")
	mat.set_shader_parameter("grain", preload("res://assets/terrain/surface_noise.tres"))
	mesh.surface_set_material(0, mat)
	return mesh


## Thin, soft lines along the cell borders, following the terrain.
func build_outline_mesh() -> ArrayMesh:
	var grid = planet.grid
	var positions := PackedVector3Array()
	for i in planet.cell_count():
		var cs: PackedVector3Array = grid.corners[i]
		var count := cs.size()
		var lifted := PackedVector3Array()
		lifted.resize(count)
		for k in count:
			var d: Vector3 = cs[k]
			lifted[k] = d * (maxf(surface_radius(d, i), SEA_LEVEL) + 0.0025)
		var center: Vector3 = grid.centers[i]
		for k in count:
			var a := lifted[k]
			var b := lifted[(k + 1) % count]
			var a_in := a.lerp(center * a.length(), 0.025)
			var b_in := b.lerp(center * b.length(), 0.025)
			positions.append_array(PackedVector3Array([a, b, b_in, a, b_in, a_in]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.98, 0.92, 0.10)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	mesh.surface_set_material(0, mat)
	return mesh


## Subdivided icosahedron: [unit vertices, triangle indices].
static func _icosphere(subdivisions: int) -> Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	# Typed Array (passed by reference) so _mid() can append to it.
	var verts: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	for i in verts.size():
		verts[i] = verts[i].normalized()
	var faces := PackedInt32Array([
		0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11,
		1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
		3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9,
		4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1,
	])
	for s in subdivisions:
		var cache := {}
		var next := PackedInt32Array()
		for f in range(0, faces.size(), 3):
			var a := faces[f]
			var b := faces[f + 1]
			var c := faces[f + 2]
			var ab := _mid(a, b, verts, cache)
			var bc := _mid(b, c, verts, cache)
			var ca := _mid(c, a, verts, cache)
			next.append_array(PackedInt32Array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca]))
		faces = next
	return [PackedVector3Array(verts), faces]


static func _mid(i: int, j: int, verts: Array[Vector3], cache: Dictionary) -> int:
	var key := mini(i, j) * 1000003 + maxi(i, j)
	if cache.has(key):
		return cache[key]
	verts.append(((verts[i] + verts[j]) * 0.5).normalized())
	cache[key] = verts.size() - 1
	return verts.size() - 1
