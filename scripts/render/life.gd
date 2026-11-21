## A little life on the planet (rendering only, no game rules):
##   - villagers walking between the town hall and the buildings,
##   - birds gliding and flapping above the land,
##   - smoke rising from the town hall, campfires, ovens and workshops.
## Everything is drawn with MultiMeshes / a few particles: cheap on iPhone.
extends Node3D

const MAX_WALKERS := 40
const BIRD_COUNT := 9
const WALK_SPEED := 0.035     # Radians per second at x1.
const SMOKY := {"townhall": 0.075, "campfire": 0.02, "bakery": 0.04, "workshop": 0.045}
const CLOTHES := [Color("f2786a"), Color("5bb5a2"), Color("ffc857"), Color("8ecae6"), Color("c9a7ff"), Color("f4a261")]

var view   # PlanetView (terrain sampler, planet, economy)
var _walkers: Array = []
var _bodies: MultiMesh
var _heads: MultiMesh
var _birds: MultiMesh
var _bird_paths: Array = []
var _smoke_root: Node3D
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_view) -> void:
	view = p_view
	_rng.seed = view._world_seed + 5
	_bodies = _make_multimesh(_body_mesh(), MAX_WALKERS, true)
	_heads = _make_multimesh(_head_mesh(), MAX_WALKERS, false)
	_birds = _make_multimesh(_bird_mesh(), BIRD_COUNT, false)
	for i in BIRD_COUNT:
		var axis := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
		var start := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
		_bird_paths.append({"axis": axis, "start": start, "phase": _rng.randf() * TAU,
			"radius": _rng.randf_range(1.18, 1.3), "speed": _rng.randf_range(0.12, 0.22) * (1 if _rng.randf() < 0.5 else -1)})
	_smoke_root = Node3D.new()
	add_child(_smoke_root)
	if view.economy != null:
		view.economy.changed.connect(refresh_smoke)
	refresh_smoke()


func _process(delta: float) -> void:
	var speed := 1.0
	if GameState and GameState.sim:
		speed = float(GameState.sim.speed)
	_time += delta * maxf(speed, 0.0)
	_update_walkers(delta * speed)
	_update_birds()


# --- Villagers -------------------------------------------------------------------

func _destinations() -> Array:
	var out: Array = []
	var eco = view.economy
	if eco == null:
		return out
	for cell in eco.building_cells():
		if eco.is_active(cell):
			out.append(cell)
	return out


func _update_walkers(dt: float) -> void:
	var eco = view.economy
	if eco == null:
		return
	var places := _destinations()
	if places.is_empty():
		_bodies.visible_instance_count = 0
		_heads.visible_instance_count = 0
		return
	var wanted := clampi(eco.population, 0, MAX_WALKERS)
	while _walkers.size() < wanted:
		var home: int = eco.village_center if eco.village_center >= 0 else places[0]
		_walkers.append({"from": home, "to": places[_rng.randi() % places.size()], "t": _rng.randf(),
			"wait": _rng.randf() * 2.0, "color": CLOTHES[_walkers.size() % CLOTHES.size()],
			"offset": Vector2(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.35, 0.35))})
	while _walkers.size() > wanted:
		_walkers.pop_back()
	var grid = view.planet.grid
	var s: float = view._object_scale
	for i in _walkers.size():
		var w: Dictionary = _walkers[i]
		if not (int(w.to) < view.planet.cell_count()) or view.planet.buildings[int(w.to)] == "":
			w.to = places[_rng.randi() % places.size()]
		var a: Vector3 = _spot(grid, int(w.from), w.offset)
		var b: Vector3 = _spot(grid, int(w.to), w.offset)
		var walking := false
		if float(w.wait) > 0.0:
			w.wait = float(w.wait) - dt
		else:
			var dist := maxf(a.angle_to(b), 0.001)
			w.t = float(w.t) + dt * WALK_SPEED / dist
			walking = true
			if float(w.t) >= 1.0:
				w.from = w.to
				w.to = places[_rng.randi() % places.size()] if _rng.randf() < 0.6 else eco.village_center
				w.t = 0.0
				w.wait = _rng.randf_range(0.5, 3.0)
				a = b
		var k := float(w.t)
		var dir := a.slerp(b, k * k * (3.0 - 2.0 * k)) if walking else a
		var radius := maxf(view.terrain.surface_radius(dir, int(w.from)), 1.0)
		var bob := absf(sin(_time * 11.0 + i)) * 0.0012 if walking else 0.0
		var basis := Basis(Quaternion(Vector3.UP, dir)) * Basis.from_scale(Vector3.ONE * s)
		var foot := dir * (radius + 0.0045 * s + bob)
		_bodies.set_instance_transform(i, Transform3D(basis, foot))
		_bodies.set_instance_color(i, w.color)
		_heads.set_instance_transform(i, Transform3D(basis, foot + dir * 0.0072 * s))
	_bodies.visible_instance_count = _walkers.size()
	_heads.visible_instance_count = _walkers.size()


## A point near the cell center, different for each walker (no queue).
func _spot(grid, cell: int, offset: Vector2) -> Vector3:
	var center: Vector3 = grid.centers[cell]
	var cs: PackedVector3Array = grid.corners[cell]
	var side := (cs[0] - center)
	var other := (cs[1] - center)
	return (center + side * offset.x * 0.8 + other * offset.y * 0.8).normalized()


# --- Birds -----------------------------------------------------------------------

func _update_birds() -> void:
	for i in BIRD_COUNT:
		var p: Dictionary = _bird_paths[i]
		var angle: float = float(p.phase) + _time * float(p.speed)
		var axis: Vector3 = p.axis
		var dir := Vector3(p.start).rotated(axis, angle)
		var ahead := Vector3(p.start).rotated(axis, angle + 0.05 * signf(float(p.speed)))
		var forward := (ahead - dir).normalized()
		var flap := 0.35 + 0.65 * absf(sin(_time * 7.0 + i * 1.3))
		var basis := Basis.looking_at(forward, dir) * Basis.from_scale(Vector3(1.0, flap, 1.0) * view._object_scale * 1.3)
		_birds.set_instance_transform(i, Transform3D(basis, dir * float(p.radius)))


# --- Smoke -----------------------------------------------------------------------

func refresh_smoke() -> void:
	for child in _smoke_root.get_children():
		child.queue_free()
	var eco = view.economy
	if eco == null:
		return
	for cell in eco.building_cells():
		var id: String = view.planet.buildings[cell]
		if not SMOKY.has(id) or not eco.is_active(cell):
			continue
		var dir: Vector3 = view.planet.grid.centers[cell]
		var s: float = view._object_scale
		var height: float = float(SMOKY[id]) * (1.0 + 0.09 * float(eco.townhall_level - 1) if id == "townhall" else 1.0)
		var smoke := _make_smoke(s)
		smoke.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), dir * (view._heights[cell] + height * s))
		_smoke_root.add_child(smoke)


func _make_smoke(s: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 7
	p.lifetime = 3.2
	p.local_coords = true
	p.direction = Vector3.UP
	p.spread = 14.0
	p.gravity = Vector3(0.0, 0.0025 * s, 0.0)
	p.initial_velocity_min = 0.004 * s
	p.initial_velocity_max = 0.007 * s
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.6))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.75))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = fade
	var puff := SphereMesh.new()
	puff.radius = 0.004 * s
	puff.height = 0.008 * s
	puff.radial_segments = 8
	puff.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.94, 0.92)
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = mat
	p.mesh = puff
	return p


# --- Meshes ----------------------------------------------------------------------

func _make_multimesh(mesh: Mesh, count: int, colored: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colored
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0 if count == MAX_WALKERS else count
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return mm


func _body_mesh() -> Mesh:
	var m := CapsuleMesh.new()
	m.radius = 0.0026
	m.height = 0.009
	m.radial_segments = 8
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	m.material = mat
	return m


func _head_mesh() -> Mesh:
	var m := SphereMesh.new()
	m.radius = 0.0021
	m.height = 0.0042
	m.radial_segments = 8
	m.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("f2c79b")
	mat.roughness = 1.0
	m.material = mat
	return m


## A soft "V" of two wings; flapping = scaling the wings up and down.
func _bird_mesh() -> Mesh:
	var verts := PackedVector3Array([
		Vector3(-0.012, 0.004, 0.002), Vector3(0, 0, -0.003), Vector3(0, 0, 0.004),
		Vector3(0.012, 0.004, 0.002), Vector3(0, 0, 0.004), Vector3(0, 0, -0.003),
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("5d5470")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_set_material(0, mat)
	return mesh
