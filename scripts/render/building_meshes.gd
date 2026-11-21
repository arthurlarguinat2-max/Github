## Builds the low-poly 3D model of each building from simple shapes.
## Sizes are in planet units (planet radius = 1, a cell is ~0.2 across).
## Emissive parts (fire, windows) glow at night. Meshes/materials are shared.
extends RefCounted

static var _materials := {}
static var _meshes := {}

const COLORS := {
	"wall": Color(0.55, 0.38, 0.22),
	"straw": Color(0.86, 0.71, 0.36),
	"roof": Color(0.42, 0.27, 0.16),
	"stone": Color(0.56, 0.55, 0.53),
	"rock": Color(0.66, 0.64, 0.6),
	"log": Color(0.45, 0.3, 0.17),
	"bush": Color(0.24, 0.55, 0.26),
	"berry": Color(0.85, 0.18, 0.25),
	"accent": Color(0.85, 0.71, 0.36),
	"water": Color(0.29, 0.64, 0.94),
	"grain": Color(0.91, 0.76, 0.35),
	"soil": Color(0.48, 0.32, 0.18),
	"plaster": Color(0.91, 0.88, 0.82),
	"clay": Color(0.69, 0.48, 0.32),
	"grass": Color(0.43, 0.64, 0.35),
	"cross": Color(0.9, 0.28, 0.3),
}
const GLOW := {
	"fire": [Color(1.0, 0.55, 0.15), 3.0],
	"window": [Color(1.0, 0.8, 0.45), 1.6],
}


static func create(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = id
	match id:
		"hut":
			_add(root, _cylinder(0.022, 0.024, 0.022, 7), "wall", Vector3(0, 0.011, 0))
			_add(root, _cylinder(0.0, 0.033, 0.028, 7), "accent", Vector3(0, 0.036, 0))
			_add(root, _box(Vector3(0.008, 0.01, 0.003)), "window", Vector3(0, 0.01, 0.022))
		"campfire":
			for k in 6:
				var a := TAU * k / 6.0
				_add(root, _sphere(0.006), "stone", Vector3(cos(a) * 0.016, 0.003, sin(a) * 0.016))
			_add(root, _cylinder(0.0, 0.009, 0.026, 6), "fire", Vector3(0, 0.013, 0))
			_add(root, _cylinder(0.003, 0.003, 0.03, 5), "log", Vector3(0, 0.004, 0), Vector3(0, 0, PI / 2))
			_add(root, _cylinder(0.003, 0.003, 0.03, 5), "log", Vector3(0, 0.004, 0), Vector3(PI / 2, 0, 0))
		"gatherer":
			for p in [Vector3(-0.018, 0.009, 0.005), Vector3(0.016, 0.008, -0.008), Vector3(0.002, 0.009, 0.018)]:
				_add(root, _sphere(0.012), "bush", p)
				_add(root, _sphere(0.004), "berry", p + Vector3(0.005, 0.007, 0.006))
			_add(root, _cylinder(0.008, 0.006, 0.01, 6), "straw", Vector3(0.0, 0.005, -0.012))
		"woodcutter":
			_add(root, _box(Vector3(0.03, 0.02, 0.024)), "wall", Vector3(-0.01, 0.01, 0))
			_add(root, _prism(Vector3(0.034, 0.014, 0.028)), "accent", Vector3(-0.01, 0.027, 0))
			_add(root, _box(Vector3(0.006, 0.008, 0.002)), "window", Vector3(-0.01, 0.01, 0.0125))
			for k in 3:
				_add(root, _cylinder(0.004, 0.004, 0.026, 6), "log",
					Vector3(0.021, 0.004 + 0.007 * (k / 2), -0.006 + 0.008 * (k % 2) + 0.004 * (k / 2)), Vector3(PI / 2, 0, 0))
		"quarry":
			_add(root, _box(Vector3(0.024, 0.018, 0.02)), "rock", Vector3(-0.01, 0.009, -0.006), Vector3(0, 0.4, 0))
			_add(root, _box(Vector3(0.016, 0.012, 0.016)), "stone", Vector3(0.013, 0.006, 0.008), Vector3(0, -0.3, 0))
			_add(root, _box(Vector3(0.012, 0.01, 0.012)), "rock", Vector3(0.0, 0.023, -0.004), Vector3(0, 0.9, 0))
		"field":
			_add(root, _box(Vector3(0.05, 0.004, 0.05)), "soil", Vector3(0, 0.002, 0))
			for k in 4:
				_add(root, _box(Vector3(0.046, 0.008, 0.006)), "grain", Vector3(0, 0.007, -0.018 + 0.012 * k))
		"mill":
			_add(root, _cylinder(0.018, 0.02, 0.008, 10), "stone", Vector3(0, 0.004, 0))
			_add(root, _cylinder(0.016, 0.016, 0.006, 10), "rock", Vector3(0, 0.011, 0))
			_add(root, _cylinder(0.002, 0.002, 0.03, 5), "log", Vector3(0, 0.026, 0))
			_add(root, _cylinder(0.002, 0.002, 0.03, 5), "log", Vector3(0, 0.03, 0), Vector3(0, 0, PI / 2))
		"bakery":
			_add(root, _sphere(0.02), "clay", Vector3(0, 0.004, 0))
			_add(root, _box(Vector3(0.01, 0.008, 0.004)), "fire", Vector3(0, 0.006, 0.019))
			_add(root, _cylinder(0.004, 0.005, 0.02, 6), "stone", Vector3(0.01, 0.024, -0.008))
		"well":
			_add(root, _cylinder(0.013, 0.014, 0.012, 10), "stone", Vector3(0, 0.006, 0))
			_add(root, _cylinder(0.01, 0.01, 0.002, 10), "water", Vector3(0, 0.0125, 0))
			_add(root, _box(Vector3(0.003, 0.026, 0.003)), "log", Vector3(-0.013, 0.019, 0))
			_add(root, _box(Vector3(0.003, 0.026, 0.003)), "log", Vector3(0.013, 0.019, 0))
			_add(root, _prism(Vector3(0.034, 0.01, 0.02)), "accent", Vector3(0, 0.036, 0))
		"workshop":
			_add(root, _box(Vector3(0.032, 0.02, 0.026)), "wall", Vector3(0, 0.01, 0))
			_add(root, _prism(Vector3(0.036, 0.014, 0.03)), "accent", Vector3(0, 0.027, 0))
			_add(root, _box(Vector3(0.008, 0.008, 0.002)), "fire", Vector3(0.006, 0.008, 0.0135))
			_add(root, _box(Vector3(0.01, 0.006, 0.008)), "stone", Vector3(-0.022, 0.003, 0.01))
		"healer":
			_add(root, _box(Vector3(0.028, 0.02, 0.024)), "plaster", Vector3(0, 0.01, 0))
			_add(root, _prism(Vector3(0.032, 0.014, 0.028)), "bush", Vector3(0, 0.027, 0))
			_add(root, _box(Vector3(0.008, 0.002, 0.002)), "cross", Vector3(0, 0.012, 0.0125))
			_add(root, _box(Vector3(0.002, 0.008, 0.002)), "cross", Vector3(0, 0.012, 0.0125))
			_add(root, _sphere(0.006), "bush", Vector3(0.02, 0.004, 0.01))
		"stone_circle":
			_add(root, _cylinder(0.026, 0.026, 0.002, 12), "grass", Vector3(0, 0.001, 0))
			for k in 6:
				var a := TAU * k / 6.0
				_add(root, _box(Vector3(0.006, 0.022, 0.005)), "stone", Vector3(cos(a) * 0.02, 0.011, sin(a) * 0.02), Vector3(0, -a, 0))
			_add(root, _cylinder(0.0, 0.005, 0.012, 6), "fire", Vector3(0, 0.007, 0))
		_:
			_add(root, _box(Vector3(0.02, 0.02, 0.02)), "berry", Vector3(0, 0.01, 0))
	return root


## Village color chosen by the player (roofs). Updates existing buildings too,
## since the material is shared.
static func set_accent(color: Color) -> void:
	_material("accent").albedo_color = color


static func _add(parent: Node3D, mesh: Mesh, material_key: String, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(material_key)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation = rot
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


static func _sphere(radius: float) -> Mesh:
	var key := "sph_%s" % radius
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = radius
		m.height = radius * 2.0
		m.radial_segments = 6
		m.rings = 3
		_meshes[key] = m
	return _meshes[key]


static func _box(size: Vector3) -> Mesh:
	var key := "box_%s" % size
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]


static func _prism(size: Vector3) -> Mesh:
	var key := "prism_%s" % size
	if not _meshes.has(key):
		var m := PrismMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]
