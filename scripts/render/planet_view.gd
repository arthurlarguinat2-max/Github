## "Hello Planète" view: a flat-shaded low-poly planet generated from a seed,
## spun with one finger (with inertia), with clouds drawn through a MultiMesh.
## Rendering only: it reads the simulation but never changes game rules.
extends Node3D

const Icosphere := preload("res://scripts/render/icosphere.gd")

const SUBDIVISIONS := 4          # 5120 triangles: cheap on any iPhone.
const SEA_LEVEL := 0.0
const RELIEF := 0.06             # Max mountain height (planet radius = 1).
const DRAG_SENSITIVITY := 0.006  # Radians per pixel.
const INERTIA_DAMPING := 3.5     # Higher = stops faster.
const CLOUD_COUNT := 18

var world_seed := 0
var _angular_velocity := Vector2.ZERO
var _active_touch := -1
var _clouds: Node3D
var _ground: MeshInstance3D


func setup(p_seed: int) -> void:
	world_seed = p_seed
	_ground = MeshInstance3D.new()
	_ground.mesh = _build_ground_mesh()
	_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ground)
	_clouds = _build_clouds()
	add_child(_clouds)


func _process(delta: float) -> void:
	if _active_touch == -1 and _angular_velocity.length_squared() > 1e-6:
		_apply_rotation(_angular_velocity * delta)
		_angular_velocity *= exp(-INERTIA_DAMPING * delta)
	# Clouds drift slowly on their own.
	_clouds.rotate_y(delta * 0.03)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _active_touch == -1:
			_active_touch = event.index
			_angular_velocity = Vector2.ZERO
		elif not event.pressed and event.index == _active_touch:
			_active_touch = -1
	elif event is InputEventScreenDrag and event.index == _active_touch:
		var step: Vector2 = event.relative * DRAG_SENSITIVITY
		_apply_rotation(step)
		# Velocity in rad/s from the finger speed, used for inertia on release.
		_angular_velocity = event.velocity * DRAG_SENSITIVITY


func _apply_rotation(step: Vector2) -> void:
	# Rotate around screen axes (camera looks down -Z, parent space = view space).
	rotate(Vector3.UP, step.x)
	rotate(Vector3.RIGHT, step.y)
	orthonormalize()


func _noise() -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = world_seed
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 1.4
	n.fractal_octaves = 4
	return n


func _height_at(noise: FastNoiseLite, p: Vector3) -> float:
	return noise.get_noise_3dv(p)


func _terrain_color(h: float, latitude: float) -> Color:
	if latitude > 0.88 or (latitude > 0.78 and h > 0.0):
		return Color("eef3f7")  # Ice caps
	if h < SEA_LEVEL - 0.18:
		return Color("2b5f9e")  # Deep ocean
	if h < SEA_LEVEL:
		return Color("3f86c6")  # Shallow water
	if h < SEA_LEVEL + 0.05:
		return Color("e8d59a")  # Beach
	if latitude < 0.25 and h < 0.2:
		return Color("d9b46a")  # Desert near the equator
	if h < 0.2:
		return Color("7cc35f")  # Plains
	if h < 0.35:
		return Color("3f8f4a")  # Forest
	if h < 0.5:
		return Color("8a8077")  # Mountain
	return Color("f4f4f4")      # Snowy peaks


func _build_ground_mesh() -> ArrayMesh:
	var noise := _noise()
	var sphere := Icosphere.build(SUBDIVISIONS)
	var base: PackedVector3Array = sphere.vertices
	# Displace each shared vertex once so the surface stays watertight.
	var displaced := PackedVector3Array()
	displaced.resize(base.size())
	for i in base.size():
		var h := maxf(_height_at(noise, base[i]), SEA_LEVEL)
		displaced[i] = base[i] * (1.0 + h * RELIEF)

	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for f in sphere.faces:
		var a := displaced[f[0]]
		var b := displaced[f[1]]
		var c := displaced[f[2]]
		var center := (base[f[0]] + base[f[1]] + base[f[2]]).normalized()
		var normal := (b - a).cross(c - a).normalized()
		# Godot front faces are clockwise: make the normal computed with the
		# CCW convention point inward, then flip it for lighting.
		if normal.dot(center) > 0.0:
			var tmp := b
			b = c
			c = tmp
		else:
			normal = -normal
		var color := _terrain_color(_height_at(noise, center), absf(center.y))
		for v in [a, b, c]:
			positions.append(v)
			normals.append(normal)
			colors.append(color)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mesh.surface_set_material(0, mat)
	return mesh


func _build_clouds() -> Node3D:
	var pivot := Node3D.new()
	var blob := SphereMesh.new()
	blob.radius = 0.09
	blob.height = 0.11
	blob.radial_segments = 7
	blob.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.92)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	blob.material = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = blob
	mm.instance_count = CLOUD_COUNT
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 1
	for i in CLOUD_COUNT:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.7, 0.7), rng.randf_range(-1, 1)).normalized()
		var orient := Basis.looking_at(dir).rotated(dir, rng.randf() * TAU)
		orient = orient * Basis.from_scale(Vector3(rng.randf_range(1.0, 2.2), rng.randf_range(0.6, 1.0), 1.0))
		mm.set_instance_transform(i, Transform3D(orient, dir * 1.16))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(instance)
	return pivot
