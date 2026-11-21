## Builds the 3D model of each building from soft, rounded shapes: round
## walls, domed thatch roofs, pebbles, logs and boulders (no boxes, except
## a few planks). Sizes are in planet units (planet radius = 1).
## Emissive parts (fire, windows) glow at night. Meshes/materials are shared.
extends RefCounted

static var _materials := {}
static var _meshes := {}

const COLORS := {
	"wall": Color(0.62, 0.44, 0.28),
	"daub": Color(0.86, 0.76, 0.6),
	"straw": Color(0.88, 0.74, 0.42),
	"stone": Color(0.62, 0.6, 0.57),
	"rock": Color(0.7, 0.67, 0.62),
	"log": Color(0.5, 0.34, 0.2),
	"bark": Color(0.42, 0.29, 0.18),
	"bush": Color(0.3, 0.6, 0.32),
	"berry": Color(0.88, 0.24, 0.3),
	"accent": Color(0.85, 0.71, 0.36),
	"water": Color(0.36, 0.7, 0.92),
	"grain": Color(0.93, 0.79, 0.4),
	"soil": Color(0.52, 0.36, 0.22),
	"plaster": Color(0.93, 0.9, 0.84),
	"clay": Color(0.75, 0.52, 0.36),
	"grass": Color(0.47, 0.7, 0.4),
	"cross": Color(0.9, 0.28, 0.3),
	"cloth": Color(0.95, 0.92, 0.85),
	"door": Color(0.36, 0.24, 0.15),
}
const GLOW := {
	"fire": [Color(1.0, 0.55, 0.15), 3.0],
	"ember": [Color(1.0, 0.82, 0.35), 2.2],
	"window": [Color(1.0, 0.82, 0.5), 1.6],
}


## `level` only matters for the town hall, which grows with each level.
static func create(id: String, level: int = 1) -> Node3D:
	var root := Node3D.new()
	root.name = id
	match id:
		"townhall":
			_townhall(root, level)
		"hut":
			_round_house(root, 0.024, 0.022, "straw", true)
		"longhouse":
			_add(root, _capsule(0.016, 0.07), "daub", Vector3(0, 0.011, 0), Vector3(0, 0, PI / 2), Vector3(1, 0.75, 0.95))
			_add(root, _capsule(0.021, 0.078), "accent", Vector3(0, 0.024, 0), Vector3(0, 0, PI / 2), Vector3(1, 0.6, 1))
			_add(root, _sphere(0.0035, 6), "window", Vector3(-0.015, 0.012, 0.0145), Vector3.ZERO, Vector3(1, 1.2, 0.4))
			_add(root, _sphere(0.0035, 6), "window", Vector3(0.015, 0.012, 0.0145), Vector3.ZERO, Vector3(1, 1.2, 0.4))
			_add(root, _capsule(0.004, 0.014), "door", Vector3(0, 0.006, 0.0155), Vector3.ZERO, Vector3(1, 1, 0.4))
		"campfire":
			_pebble_ring(root, 0.016, 7, 0.006)
			for k in 3:
				_add(root, _capsule(0.0024, 0.028), "log", Vector3(0, 0.004, 0), Vector3(PI / 2 - 0.25, TAU * k / 3.0, 0))
			_add(root, _sphere(0.007, 8), "fire", Vector3(0, 0.009, 0), Vector3.ZERO, Vector3(1, 1.5, 1))
			_add(root, _sphere(0.004, 8), "ember", Vector3(0, 0.017, 0), Vector3.ZERO, Vector3(1, 1.8, 1))
		"gatherer":
			for p in [Vector3(-0.018, 0.008, 0.004), Vector3(0.016, 0.007, -0.008), Vector3(0.002, 0.009, 0.017), Vector3(-0.004, 0.007, -0.016)]:
				_add(root, _sphere(0.011, 10), "bush", p, Vector3.ZERO, Vector3(1, 0.8, 1))
				_add(root, _sphere(0.0028, 6), "berry", p + Vector3(0.005, 0.006, 0.006))
				_add(root, _sphere(0.0024, 6), "berry", p + Vector3(-0.006, 0.005, 0.004))
			_add(root, _cylinder(0.008, 0.006, 0.009, 12), "straw", Vector3(0.0, 0.0045, -0.002))
			_add(root, _torus(0.0055, 0.0085), "wall", Vector3(0.0, 0.009, -0.002))
		"woodcutter":
			_round_house(root, 0.018, 0.018, "accent", false, Vector3(-0.012, 0, 0))
			for k in 3:
				_add(root, _capsule(0.0038, 0.026), "log",
					Vector3(0.018, 0.004 + 0.0065 * (k / 2), -0.008 + 0.0078 * (k % 2) + 0.0039 * (k / 2)), Vector3(PI / 2, 0, 0))
			_add(root, _cylinder(0.006, 0.007, 0.006, 12), "bark", Vector3(0.006, 0.003, 0.016))
		"quarry":
			_boulder(root, Vector3(-0.012, 0.009, -0.006), Vector3(0.026, 0.02, 0.022), "rock", 0.4)
			_boulder(root, Vector3(0.013, 0.006, 0.008), Vector3(0.018, 0.013, 0.016), "stone", -0.3)
			_boulder(root, Vector3(0.0, 0.021, -0.006), Vector3(0.012, 0.01, 0.011), "rock", 0.9)
			_add(root, _cylinder(0.006, 0.006, 0.008, 6), "stone", Vector3(0.018, 0.004, -0.012), Vector3(0, 0.3, 0))
		"field":
			_add(root, _cylinder(0.03, 0.031, 0.003, 18), "soil", Vector3(0, 0.0015, 0), Vector3.ZERO, Vector3(1, 1, 0.85))
			for k in 4:
				var z := -0.018 + 0.012 * k
				var half := sqrt(maxf(0.0, 0.028 * 0.028 - z * z))
				_add(root, _capsule(0.0035, maxf(half * 2.0, 0.012)), "grain", Vector3(0, 0.005, z * 0.85), Vector3(0, 0, PI / 2), Vector3(1, 0.9, 1))
		"mill":
			_add(root, _cylinder(0.019, 0.021, 0.008, 18), "stone", Vector3(0, 0.004, 0))
			_add(root, _cylinder(0.016, 0.016, 0.006, 18), "rock", Vector3(0, 0.011, 0))
			_add(root, _torus(0.013, 0.017), "stone", Vector3(0, 0.0145, 0))
			_add(root, _capsule(0.0018, 0.034), "log", Vector3(0, 0.026, 0))
			_add(root, _capsule(0.0018, 0.034), "log", Vector3(0, 0.03, 0), Vector3(0, 0, PI / 2))
		"bakery":
			_add(root, _dome(0.021, 0.02), "clay", Vector3(0, 0.0, 0))
			_add(root, _sphere(0.006, 8), "fire", Vector3(0, 0.005, 0.017), Vector3.ZERO, Vector3(1, 0.8, 0.5))
			_add(root, _cylinder(0.004, 0.005, 0.016, 10), "stone", Vector3(0.009, 0.022, -0.007))
		"well":
			_add(root, _cylinder(0.013, 0.014, 0.011, 16), "stone", Vector3(0, 0.0055, 0))
			_add(root, _torus(0.011, 0.0145), "rock", Vector3(0, 0.011, 0))
			_add(root, _cylinder(0.0105, 0.0105, 0.0015, 16), "water", Vector3(0, 0.0105, 0))
			_add(root, _capsule(0.0016, 0.03), "log", Vector3(-0.013, 0.02, 0))
			_add(root, _capsule(0.0016, 0.03), "log", Vector3(0.013, 0.02, 0))
			_add(root, _dome(0.018, 0.012), "accent", Vector3(0, 0.032, 0), Vector3.ZERO, Vector3(1, 1, 0.75))
		"workshop":
			_round_house(root, 0.021, 0.019, "accent", true)
			_add(root, _sphere(0.004, 6), "fire", Vector3(0.012, 0.007, 0.018), Vector3.ZERO, Vector3(1, 1, 0.5))
			_boulder(root, Vector3(-0.024, 0.004, 0.012), Vector3(0.012, 0.008, 0.01), "stone", 0.2)
		"healer":
			_round_house(root, 0.02, 0.019, "bush", true)
			_add(root, _capsule(0.0012, 0.008), "cross", Vector3(0, 0.03, 0.0), Vector3(0, 0, PI / 2))
			_add(root, _capsule(0.0012, 0.008), "cross", Vector3(0, 0.03, 0.0))
			for p in [Vector3(0.024, 0.004, 0.008), Vector3(0.02, 0.004, -0.012), Vector3(-0.022, 0.004, 0.01)]:
				_add(root, _sphere(0.005, 8), "bush", p, Vector3.ZERO, Vector3(1, 0.8, 1))
		"stone_circle":
			_add(root, _cylinder(0.027, 0.028, 0.002, 18), "grass", Vector3(0, 0.001, 0))
			for k in 7:
				var a := TAU * k / 7.0
				_add(root, _capsule(0.0032, 0.022), "stone", Vector3(cos(a) * 0.02, 0.01, sin(a) * 0.02), Vector3(0.12 * sin(a * 3.0), -a, 0.1), Vector3(1, 1, 0.7))
			_add(root, _sphere(0.004, 8), "fire", Vector3(0, 0.005, 0), Vector3.ZERO, Vector3(1, 1.6, 1))
		"outpost":
			_add(root, _capsule(0.0015, 0.064), "log", Vector3(0, 0.032, 0))
			_add(root, _sphere(0.009, 8), "accent", Vector3(0.008, 0.055, 0), Vector3.ZERO, Vector3(1.1, 0.6, 0.15))
			_add(root, _dome(0.016, 0.017), "cloth", Vector3(-0.012, 0.0, 0.01))
			_add(root, _capsule(0.003, 0.009), "door", Vector3(-0.012, 0.004, 0.025), Vector3.ZERO, Vector3(1, 1, 0.4))
		_:
			_add(root, _sphere(0.012, 8), "berry", Vector3(0, 0.012, 0))
	return root


## Round wattle house with a domed thatch roof (and a little top knob).
static func _round_house(root: Node3D, radius: float, wall_h: float, roof: String, knob: bool, at: Vector3 = Vector3.ZERO) -> void:
	_add(root, _cylinder(radius * 0.92, radius, wall_h, 14), "daub", at + Vector3(0, wall_h * 0.5, 0))
	_add(root, _dome(radius * 1.32, radius * 1.15), roof, at + Vector3(0, wall_h * 0.82, 0))
	if knob:
		_add(root, _sphere(radius * 0.18, 8), roof, at + Vector3(0, wall_h * 0.82 + radius * 1.12, 0))
	_add(root, _capsule(radius * 0.22, radius * 0.62), "door", at + Vector3(0, radius * 0.3, radius * 0.97), Vector3.ZERO, Vector3(1, 1, 0.35))
	_add(root, _sphere(radius * 0.14, 6), "window", at + Vector3(radius * 0.66, wall_h * 0.55, radius * 0.66), Vector3.ZERO, Vector3(1, 1.2, 0.45))


## Town hall: a big round hall with a dome; a stone ring from level 2, an
## upper hall from level 3, a round tower from level 4; grows every level.
static func _townhall(root: Node3D, level: int) -> void:
	var s := 1.0 + 0.09 * float(level - 1)
	var base_h := 0.0
	if level >= 2:
		_add(root, _cylinder(0.042 * s, 0.045 * s, 0.009, 20), "stone", Vector3(0, 0.0045, 0))
		_pebble_ring(root, 0.046 * s, 12, 0.004)
		base_h = 0.009
	var wall_h := 0.026 * s
	_add(root, _cylinder(0.031 * s, 0.034 * s, wall_h, 20), "daub", Vector3(0, base_h + wall_h * 0.5, 0))
	_add(root, _dome(0.045 * s, 0.038 * s), "accent", Vector3(0, base_h + wall_h * 0.85, 0))
	_add(root, _capsule(0.008 * s, 0.02 * s), "door", Vector3(0, base_h + 0.008 * s, 0.033 * s), Vector3.ZERO, Vector3(1, 1, 0.35))
	for k in 4:
		var a := TAU * k / 4.0 + 0.6
		_add(root, _sphere(0.0045 * s, 6), "window", Vector3(cos(a) * 0.032 * s, base_h + 0.014 * s, sin(a) * 0.032 * s), Vector3(0, -a, 0), Vector3(0.45, 1.2, 1))
	var top := base_h + wall_h * 0.85 + 0.036 * s
	if level >= 3:
		_add(root, _cylinder(0.014 * s, 0.016 * s, 0.014 * s, 14), "plaster", Vector3(0, top + 0.004 * s, 0))
		_add(root, _dome(0.02 * s, 0.018 * s), "accent", Vector3(0, top + 0.01 * s, 0))
		top += 0.026 * s
	if level >= 4:
		var tower := Vector3(0.042 * s, 0, -0.022 * s)
		_add(root, _cylinder(0.009 * s, 0.011 * s, 0.06 * s, 12), "stone", tower + Vector3(0, 0.03 * s, 0))
		_add(root, _dome(0.014 * s, 0.016 * s), "accent", tower + Vector3(0, 0.058 * s, 0))
		_add(root, _sphere(0.003 * s, 6), "window", tower + Vector3(0, 0.045 * s, 0.01 * s))
	_add(root, _capsule(0.0011, 0.03), "log", Vector3(0, top + 0.012, 0))
	_add(root, _sphere(0.007, 8), "accent", Vector3(0.006, top + 0.024, 0), Vector3.ZERO, Vector3(1.1, 0.6, 0.15))


## Construction site: log posts and beams around a pile of thatch.
static func scaffold() -> Node3D:
	var root := Node3D.new()
	root.name = "scaffold"
	_add(root, _cylinder(0.026, 0.027, 0.003, 14), "soil", Vector3(0, 0.0015, 0))
	for k in 4:
		var a := TAU * k / 4.0 + 0.785
		_add(root, _capsule(0.0017, 0.032), "log", Vector3(cos(a) * 0.02, 0.016, sin(a) * 0.02))
	_add(root, _capsule(0.0015, 0.04), "log", Vector3(0, 0.03, 0.014), Vector3(0, 0, PI / 2))
	_add(root, _capsule(0.0015, 0.04), "log", Vector3(0, 0.03, -0.014), Vector3(0, 0, PI / 2))
	_add(root, _dome(0.013, 0.01), "straw", Vector3(0, 0.0, 0))
	_add(root, _capsule(0.003, 0.02), "log", Vector3(0.008, 0.004, -0.006), Vector3(PI / 2, 0.5, 0))
	return root


## Village color chosen by the player (roofs). Updates existing buildings too,
## since the material is shared.
static func set_accent(color: Color) -> void:
	_material("accent").albedo_color = color


# --- Shape helpers ------------------------------------------------------------------

static func _pebble_ring(root: Node3D, radius: float, count: int, size: float) -> void:
	for k in count:
		var a := TAU * k / float(count)
		var wobble := 0.8 + 0.4 * absf(sin(a * 5.0))
		_add(root, _sphere(size * wobble, 6), "stone", Vector3(cos(a) * radius, size * 0.5, sin(a) * radius), Vector3(0, a, 0), Vector3(1.2, 0.7, 1))


static func _boulder(root: Node3D, pos: Vector3, size: Vector3, material_key: String, turn: float) -> void:
	_add(root, _sphere(0.5, 7), material_key, pos, Vector3(0.2 * turn, turn, -0.15 * turn), size)


static func _add(parent: Node3D, mesh: Mesh, material_key: String, pos: Vector3, rot: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(material_key)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale
	parent.add_child(mi)


static func _material(key: String) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.9
	if GLOW.has(key):
		var glow: Array = GLOW[key]
		mat.albedo_color = glow[0]
		mat.emission_enabled = true
		mat.emission = glow[0]
		mat.emission_energy_multiplier = glow[1]
	else:
		mat.albedo_color = COLORS.get(key, Color.MAGENTA)
	_materials[key] = mat
	return mat


static func _cylinder(top: float, bottom: float, height: float, segments: int) -> Mesh:
	var key := "cyl_%s_%s_%s_%d" % [top, bottom, height, segments]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = height
		m.radial_segments = segments
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


static func _sphere(radius: float, segments: int = 10) -> Mesh:
	var key := "sph_%s_%d" % [radius, segments]
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = radius
		m.height = radius * 2.0
		m.radial_segments = segments
		m.rings = maxi(3, segments / 2)
		_meshes[key] = m
	return _meshes[key]


## Half sphere sitting on its flat side (roofs, ovens, tents).
static func _dome(radius: float, height: float) -> Mesh:
	var key := "dome_%s_%s" % [radius, height]
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = radius
		m.height = height  # A hemisphere spans y = 0 .. height.
		m.is_hemisphere = true
		m.radial_segments = 16
		m.rings = 6
		_meshes[key] = m
	return _meshes[key]


static func _capsule(radius: float, height: float) -> Mesh:
	var key := "cap_%s_%s" % [radius, height]
	if not _meshes.has(key):
		var m := CapsuleMesh.new()
		m.radius = radius
		m.height = maxf(height, radius * 2.0 + 0.0001)
		m.radial_segments = 10
		m.rings = 3
		_meshes[key] = m
	return _meshes[key]


static func _torus(inner: float, outer: float) -> Mesh:
	var key := "torus_%s_%s" % [inner, outer]
	if not _meshes.has(key):
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = 18
		m.ring_segments = 8
		_meshes[key] = m
	return _meshes[key]
