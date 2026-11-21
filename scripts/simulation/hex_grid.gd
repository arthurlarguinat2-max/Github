## Hexagonal tiling of the unit sphere (Goldberg polyhedron).
##
## Built as the dual of a geodesic icosphere of the given frequency:
##   cells = 10 * frequency² + 2  (frequency 6 -> 362 cells),
##   exactly 12 cells are pentagons, all others are hexagons.
## Pure geometry, deterministic, no engine node: unit-tested headless.
extends RefCounted

const ICO_FACES := [
	[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
	[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
	[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
	[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
]

var frequency := 1
## Unit vector pointing to the center of each cell.
var centers := PackedVector3Array()
## Neighbor cell indices, sorted counter-clockwise (seen from outside).
var neighbors: Array[PackedInt32Array] = []
## Polygon corners (unit vectors), sorted counter-clockwise (seen from outside).
var corners: Array[PackedVector3Array] = []


static func cell_count_for(p_frequency: int) -> int:
	return 10 * p_frequency * p_frequency + 2


func _init(p_frequency: int = 6) -> void:
	frequency = maxi(p_frequency, 1)
	var base := _icosahedron_vertices()
	var index_of := {}
	var triangles: Array[Vector3i] = []
	for face_id in ICO_FACES.size():
		var face: Array = ICO_FACES[face_id]
		var rows: Array[PackedInt32Array] = []
		for i in frequency + 1:
			var row := PackedInt32Array()
			for j in frequency + 1 - i:
				row.append(_vertex(face_id, face[0], face[1], face[2], i, j, base, index_of))
			rows.append(row)
		for i in frequency:
			for j in frequency - i:
				triangles.append(Vector3i(rows[i][j], rows[i + 1][j], rows[i][j + 1]))
				if j < frequency - 1 - i:
					triangles.append(Vector3i(rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
	_build_topology(triangles)


func cell_count() -> int:
	return centers.size()


func is_pentagon(cell: int) -> bool:
	return neighbors[cell].size() == 5


## Index of the cell containing the direction `dir` (any length).
func find_cell(dir: Vector3) -> int:
	var d := dir.normalized()
	var best := -1
	var best_dot := -INF
	for i in centers.size():
		var dot := centers[i].dot(d)
		if dot > best_dot:
			best_dot = dot
			best = i
	return best


static func _icosahedron_vertices() -> PackedVector3Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts := PackedVector3Array([
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	])
	for i in verts.size():
		verts[i] = verts[i].normalized()
	return verts


## Returns the shared vertex index for barycentric grid point (i, j) of a face.
## Points on icosahedron edges/corners use canonical keys so that the
## adjacent faces reuse exactly the same vertex (no floating-point rounding).
func _vertex(face_id: int, a: int, b: int, c: int, i: int, j: int,
		base: PackedVector3Array, index_of: Dictionary) -> int:
	var f := frequency
	var key: String
	var pos: Vector3
	if i == 0 and j == 0:
		key = "v%d" % a
		pos = base[a]
	elif i == f:
		key = "v%d" % b
		pos = base[b]
	elif j == f:
		key = "v%d" % c
		pos = base[c]
	elif j == 0:
		var e := _edge_point(a, b, i, base)
		key = e[0]
		pos = e[1]
	elif i == 0:
		var e := _edge_point(a, c, j, base)
		key = e[0]
		pos = e[1]
	elif i + j == f:
		var e := _edge_point(b, c, j, base)
		key = e[0]
		pos = e[1]
	else:
		key = "f%d_%d_%d" % [face_id, i, j]
		pos = base[a] * float(f - i - j) + base[b] * float(i) + base[c] * float(j)
	if index_of.has(key):
		return index_of[key]
	centers.append(pos.normalized())
	index_of[key] = centers.size() - 1
	return centers.size() - 1


## Point k steps (out of frequency) from vertex u toward vertex v.
func _edge_point(u: int, v: int, k: int, base: PackedVector3Array) -> Array:
	if u > v:
		var tmp := u
		u = v
		v = tmp
		k = frequency - k
	var pos := base[u].lerp(base[v], float(k) / float(frequency))
	return ["e%d_%d_%d" % [u, v, k], pos]


func _build_topology(triangles: Array[Vector3i]) -> void:
	var n := centers.size()
	var adjacency: Array[Dictionary] = []
	var triangles_of: Array[PackedInt32Array] = []
	for k in n:
		adjacency.append({})
		triangles_of.append(PackedInt32Array())
	var tri_centers := PackedVector3Array()
	for t in triangles:
		tri_centers.append((centers[t.x] + centers[t.y] + centers[t.z]).normalized())
		var ti := tri_centers.size() - 1
		triangles_of[t.x].append(ti)
		triangles_of[t.y].append(ti)
		triangles_of[t.z].append(ti)
		adjacency[t.x][t.y] = true
		adjacency[t.y][t.x] = true
		adjacency[t.y][t.z] = true
		adjacency[t.z][t.y] = true
		adjacency[t.z][t.x] = true
		adjacency[t.x][t.z] = true

	for v in n:
		var normal := centers[v]
		var t1 := _tangent(normal)
		var t2 := normal.cross(t1)
		var nb: Array = adjacency[v].keys()
		var pts := centers
		nb.sort_custom(func(p, q): return _angle(pts[p] - normal, t1, t2) < _angle(pts[q] - normal, t1, t2))
		neighbors.append(PackedInt32Array(nb))
		var cs: Array = []
		for ti in triangles_of[v]:
			cs.append(tri_centers[ti])
		cs.sort_custom(func(p, q): return _angle(p - normal, t1, t2) < _angle(q - normal, t1, t2))
		corners.append(PackedVector3Array(cs))


static func _tangent(normal: Vector3) -> Vector3:
	var helper := Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT
	return normal.cross(helper).normalized()


static func _angle(d: Vector3, t1: Vector3, t2: Vector3) -> float:
	return atan2(d.dot(t2), d.dot(t1))
