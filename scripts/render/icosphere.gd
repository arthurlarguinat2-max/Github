## Builds a subdivided icosahedron (unit sphere). Pure geometry helper.
## Phase 1 will derive the hexagonal Goldberg tiles from its dual.
extends RefCounted


## Returns { "vertices": PackedVector3Array, "faces": Array[PackedInt32Array] }.
static func build(subdivisions: int) -> Dictionary:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	for i in verts.size():
		verts[i] = verts[i].normalized()
	var faces: Array = [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	for s in subdivisions:
		var cache := {}
		var next_faces: Array = []
		for f in faces:
			var a := _midpoint(f[0], f[1], verts, cache)
			var b := _midpoint(f[1], f[2], verts, cache)
			var c := _midpoint(f[2], f[0], verts, cache)
			next_faces.append_array([[f[0], a, c], [f[1], b, a], [f[2], c, b], [a, b, c]])
		faces = next_faces
	return {"vertices": PackedVector3Array(verts), "faces": faces}


static func _midpoint(i: int, j: int, verts: Array[Vector3], cache: Dictionary) -> int:
	var key := Vector2i(mini(i, j), maxi(i, j))
	if cache.has(key):
		return cache[key]
	verts.append(((verts[i] + verts[j]) * 0.5).normalized())
	cache[key] = verts.size() - 1
	return verts.size() - 1
