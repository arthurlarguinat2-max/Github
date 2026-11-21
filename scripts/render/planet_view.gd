## Renders the hexagonal planet and handles touch controls:
##   - 1 finger drag: spin the planet (with inertia),
##   - pinch / mouse wheel: zoom,
##   - tap: select a cell (emits cell_selected).
## Rendering only: it reads the PlanetState but never changes game rules.
extends Node3D

signal cell_selected(cell: int)
signal selection_cleared

const DRAG_SENSITIVITY := 0.006   # Radians per pixel at the farthest zoom.
const INERTIA_DAMPING := 3.5      # Higher = stops faster.
const TAP_MAX_MOVE := 14.0        # Pixels: more than that is a drag, not a tap.
const TAP_MAX_TIME := 0.35        # Seconds.
const ZOOM_MIN := 1.75            # Camera distance (planet radius = 1).
const ZOOM_MAX := 4.2
const ZOOM_DEFAULT := 3.6
const PICK_RADIUS := 1.03
const CLOUD_COUNT := 18

const WATER_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	// Gentle shimmer: brightness waves travelling over the ocean.
	float wave = sin(TIME * 1.3 + local_pos.x * 23.0 + local_pos.z * 17.0)
		* sin(TIME * 0.9 + local_pos.y * 19.0);
	vec3 base = pow(COLOR.rgb, vec3(2.2)); // sRGB -> linear
	ALBEDO = base * (0.93 + 0.07 * wave);
	ROUGHNESS = 0.32;
	SPECULAR = 0.6;
}
"""

var planet          # PlanetState
var terrain_defs: Dictionary = {}
var camera: Camera3D
## Returns true when a screen point is covered by the UI (set by main.gd).
var ui_blocks_point: Callable

var selected := -1
var _heights := PackedFloat32Array()   # Top radius of each cell.
var _zoom := ZOOM_DEFAULT
var _zoom_target := ZOOM_DEFAULT
var _angular_velocity := Vector2.ZERO
var _touches := {}                    # Finger index -> last position.
var _tap_candidate := false
var _tap_start_pos := Vector2.ZERO
var _tap_start_time := 0.0
var _clouds: Node3D
var _highlight: MeshInstance3D


func setup(p_planet, p_terrain_defs: Dictionary, p_camera: Camera3D, world_seed: int) -> void:
	planet = p_planet
	terrain_defs = p_terrain_defs
	camera = p_camera
	_compute_heights()
	_build_surface(world_seed)
	_build_trees(world_seed)
	_clouds = _build_clouds(world_seed)
	add_child(_clouds)
	_highlight = MeshInstance3D.new()
	_highlight.material_override = _highlight_material()
	_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_highlight)
	_update_camera()


func _process(delta: float) -> void:
	if _touches.is_empty() and _angular_velocity.length_squared() > 1e-6:
		_apply_rotation(_angular_velocity * delta)
		_angular_velocity *= exp(-INERTIA_DAMPING * delta)
	_clouds.rotate_y(delta * 0.03)
	if absf(_zoom - _zoom_target) > 0.0005:
		_zoom = lerpf(_zoom, _zoom_target, 1.0 - exp(-10.0 * delta))
		_update_camera()


# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom_target * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom_target * 1.1)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# A first finger landing on a button belongs to the UI, not the planet.
		if _touches.is_empty() and ui_blocks_point.is_valid() and ui_blocks_point.call(event.position):
			return
		_touches[event.index] = event.position
		_angular_velocity = Vector2.ZERO
		_tap_candidate = _touches.size() == 1
		_tap_start_pos = event.position
		_tap_start_time = Time.get_ticks_msec() / 1000.0
	elif _touches.has(event.index):
		_touches.erase(event.index)
		var quick := Time.get_ticks_msec() / 1000.0 - _tap_start_time <= TAP_MAX_TIME
		if _tap_candidate and _touches.is_empty() and quick \
				and event.position.distance_to(_tap_start_pos) <= TAP_MAX_MOVE:
			_select_at(event.position)
		if _touches.is_empty():
			_tap_candidate = false


func _on_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	var previous: Vector2 = _touches[event.index]
	_touches[event.index] = event.position
	if event.position.distance_to(_tap_start_pos) > TAP_MAX_MOVE:
		_tap_candidate = false
	if _touches.size() == 1:
		var k := _rotation_scale()
		_apply_rotation(event.relative * DRAG_SENSITIVITY * k)
		_angular_velocity = event.velocity * DRAG_SENSITIVITY * k
	elif _touches.size() == 2:
		_tap_candidate = false
		var other: Vector2 = Vector2.ZERO
		for idx in _touches:
			if idx != event.index:
				other = _touches[idx]
		var before := previous.distance_to(other)
		var after := event.position.distance_to(other)
		if before > 1.0 and after > 1.0:
			_set_zoom(_zoom_target * before / after)


func _apply_rotation(step: Vector2) -> void:
	# Rotate around screen axes (the camera looks down -Z without rotation).
	rotate(Vector3.UP, step.x)
	rotate(Vector3.RIGHT, step.y)
	orthonormalize()


## Slower rotation when zoomed in, so the finger "sticks" to the ground.
func _rotation_scale() -> float:
	return clampf((_zoom - 1.0) / (ZOOM_MAX - 1.0), 0.15, 1.0)


func _set_zoom(value: float) -> void:
	_zoom_target = clampf(value, ZOOM_MIN, ZOOM_MAX)


func _update_camera() -> void:
	if camera == null:
		return
	# Far away the planet sits a bit low (room for the title); close up, centered.
	var t := (_zoom - ZOOM_MIN) / (ZOOM_MAX - ZOOM_MIN)
	camera.position = Vector3(0.0, 0.25 * t, _zoom)


# --- Selection ---------------------------------------------------------------

func _select_at(screen_pos: Vector2) -> void:
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	# Work in the planet's local space (it only rotates).
	var inv := global_transform.affine_inverse()
	var o := inv * origin
	var d := (inv.basis * direction).normalized()
	var b := o.dot(d)
	var c := o.dot(o) - PICK_RADIUS * PICK_RADIUS
	var disc := b * b - c
	if disc < 0.0:
		clear_selection()
		return
	var t := -b - sqrt(disc)
	if t < 0.0:
		t = -b + sqrt(disc)
	select_cell(planet.grid.find_cell(o + d * t))


func select_cell(cell: int) -> void:
	if cell < 0:
		clear_selection()
		return
	selected = cell
	_highlight.mesh = _build_highlight_mesh(cell)
	_highlight.visible = true
	cell_selected.emit(cell)


func clear_selection() -> void:
	if selected == -1:
		return
	selected = -1
	_highlight.visible = false
	selection_cleared.emit()


# --- Mesh building -----------------------------------------------------------

func _def(cell: int) -> Dictionary:
	return terrain_defs.get(planet.terrain[cell], {})


func _compute_heights() -> void:
	_heights.resize(planet.cell_count())
	for i in planet.cell_count():
		_heights[i] = 1.0 + float(_def(i).get("height", 0.0))


func _build_surface(world_seed: int) -> void:
	var land := MeshBuffer.new()
	var water := MeshBuffer.new()
	var grid = planet.grid
	for i in planet.cell_count():
		var def := _def(i)
		var is_water := bool(def.get("water", false))
		var buffer := water if is_water else land
		var h := _heights[i]
		var peak := float(def.get("peak", 0.0))
		# Small per-cell tint variation so neighbouring cells stay readable.
		var tint := float(posmod(hash(i * 7919 + world_seed), 100)) / 100.0
		var color := Color(str(def.get("color", "ff00ff"))).darkened(tint * 0.09)
		var peak_color := Color(str(def.get("peak_color", color.to_html(false))))
		var center: Vector3 = grid.centers[i]
		var cs: PackedVector3Array = grid.corners[i]
		var top := center * (h + peak)
		var count := cs.size()
		for k in count:
			var c0 := cs[k]
			var c1 := cs[(k + 1) % count]
			buffer.add_tri(top, c0 * h, c1 * h, peak_color, color, color, center)
			# Wall down to the lower neighbour across this edge (visible relief).
			var mid := (c0 + c1).normalized()
			var nb := _neighbor_across(i, mid)
			var nh := _heights[nb] if nb >= 0 else 1.0
			if nh < h - 0.0001:
				var wall := color.darkened(0.22)
				var outward := mid - center
				buffer.add_tri(c0 * h, c1 * h, c1 * nh, wall, wall, wall, outward)
				buffer.add_tri(c0 * h, c1 * nh, c0 * nh, wall, wall, wall, outward)

	var land_mat := StandardMaterial3D.new()
	land_mat.vertex_color_use_as_albedo = true
	land_mat.vertex_color_is_srgb = true
	land_mat.roughness = 0.95
	land_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_add_mesh(land.to_mesh(land_mat))

	var water_mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = WATER_SHADER
	water_mat.shader = shader
	_add_mesh(water.to_mesh(water_mat))


func _neighbor_across(cell: int, edge_dir: Vector3) -> int:
	var best := -1
	var best_dot := -INF
	for nb in planet.grid.neighbors[cell]:
		var dot: float = planet.grid.centers[nb].dot(edge_dir)
		if dot > best_dot:
			best_dot = dot
			best = nb
	return best


func _add_mesh(mesh: ArrayMesh) -> void:
	if mesh == null:
		return
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


## Low-poly trees drawn in a single MultiMesh (one draw call for all of them).
func _build_trees(world_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 31
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var grid = planet.grid
	for i in planet.cell_count():
		var amount := 0
		match planet.terrain[i]:
			"forest":
				amount = rng.randi_range(4, 6)
			"plains":
				amount = 1 if rng.randf() < 0.3 else 0
			"hills":
				amount = 1 if rng.randf() < 0.4 else 0
		var cs: PackedVector3Array = grid.corners[i]
		for t in amount:
			var corner := cs[rng.randi() % cs.size()]
			var dir: Vector3 = (grid.centers[i] as Vector3).lerp(corner, rng.randf_range(0.15, 0.6)).normalized()
			var s := rng.randf_range(0.8, 1.3)
			var orient := Basis(Quaternion(Vector3.UP, dir)) * Basis.from_scale(Vector3.ONE * s)
			transforms.append(Transform3D(orient, dir * (_heights[i] + 0.02 * s)))
			colors.append(Color(0.16, 0.42, 0.2).lerp(Color(0.3, 0.55, 0.22), rng.randf()))
	if transforms.is_empty():
		return
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.014
	cone.height = 0.04
	cone.radial_segments = 6
	cone.rings = 1
	cone.cap_top = false
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	cone.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cone
	mm.instance_count = transforms.size()
	for k in transforms.size():
		mm.set_instance_transform(k, transforms[k])
		mm.set_instance_color(k, colors[k])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _build_clouds(world_seed: int) -> Node3D:
	var pivot := Node3D.new()
	var blob := SphereMesh.new()
	blob.radius = 0.09
	blob.height = 0.11
	blob.radial_segments = 7
	blob.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.9)
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
		mm.set_instance_transform(i, Transform3D(orient, dir * 1.2))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(instance)
	return pivot


## Bright ring along the border of the selected cell.
func _build_highlight_mesh(cell: int) -> ArrayMesh:
	var buffer := MeshBuffer.new()
	var center: Vector3 = planet.grid.centers[cell]
	var cs: PackedVector3Array = planet.grid.corners[cell]
	var h := _heights[cell] + 0.004
	var peak := float(_def(cell).get("peak", 0.0))
	var inner_h := h + peak * 0.22
	var white := Color.WHITE
	for k in cs.size():
		var a := cs[k]
		var b := cs[(k + 1) % cs.size()]
		var a_in := center.lerp(a, 0.78).normalized()
		var b_in := center.lerp(b, 0.78).normalized()
		buffer.add_tri(a * h, b * h, b_in * inner_h, white, white, white, center)
		buffer.add_tri(a * h, b_in * inner_h, a_in * inner_h, white, white, white, center)
	return buffer.to_mesh(null)


func _highlight_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.95, 0.7, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 1
	return mat


## Accumulates flat-shaded triangles, then builds an ArrayMesh.
class MeshBuffer:
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()

	## `outward` tells which side is the front face. Godot front faces are
	## clockwise: the CCW cross product must point inward, then is flipped.
	func add_tri(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, outward: Vector3) -> void:
		var n := (b - a).cross(c - a)
		if n.dot(outward) > 0.0:
			var tmp_v := b
			b = c
			c = tmp_v
			var tmp_c := cb
			cb = cc
			cc = tmp_c
		else:
			n = -n
		n = n.normalized()
		positions.append(a)
		positions.append(b)
		positions.append(c)
		normals.append(n)
		normals.append(n)
		normals.append(n)
		colors.append(ca)
		colors.append(cb)
		colors.append(cc)

	func to_mesh(material: Material) -> ArrayMesh:
		if positions.is_empty():
			return null
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = positions
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if material:
			mesh.surface_set_material(0, material)
		return mesh
