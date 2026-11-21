## Renders the hexagonal planet and handles touch controls:
##   - 1 finger drag: spin the planet (with inertia),
##   - pinch / mouse wheel: zoom,
##   - tap: select a cell (emits cell_selected).
## Rendering only: it reads the PlanetState but never changes game rules.
extends Node3D

signal cell_selected(cell: int)
signal selection_cleared
## For the tutorial: the player spun / zoomed the planet.
signal rotated
signal zoomed

const DRAG_SENSITIVITY := 0.006   # Radians per pixel at the farthest zoom.
const INERTIA_DAMPING := 3.5      # Higher = stops faster.
const TAP_MAX_MOVE := 14.0        # Pixels: more than that is a drag, not a tap.
const TAP_MAX_TIME := 0.35        # Seconds.
const ZOOM_MIN := 1.75            # Camera distance (planet radius = 1).
const ZOOM_MAX := 4.2
const ZOOM_DEFAULT := 3.6
const PICK_RADIUS := 1.03
const BuildingMeshes := preload("res://scripts/render/building_meshes.gd")
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
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(base * (0.95 + 0.05 * wave), vec3(1.0), rim * 0.35);
	ROUGHNESS = 0.22;
	SPECULAR = 0.7;
}
"""

var planet          # PlanetState
var terrain_defs: Dictionary = {}
var camera: Camera3D
## Returns true when a screen point is covered by the UI (set by main.gd).
var ui_blocks_point: Callable

var selected := -1
var _heights := PackedFloat32Array()   # Top radius of each cell.
var _zoom_min := ZOOM_MIN
var _zoom := ZOOM_DEFAULT
var _zoom_target := ZOOM_DEFAULT
var _angular_velocity := Vector2.ZERO
var _touches := {}                    # Finger index -> last position.
var _tap_candidate := false
var _tap_start_pos := Vector2.ZERO
var _tap_start_time := 0.0
var _clouds: Node3D
var _highlight: MeshInstance3D
var _trees: Node3D
var _buildings_root: Node3D
var _world_seed := 0
var _surface_nodes: Array[Node] = []
var _placement: MeshInstance3D
## Objects (trees, buildings) shrink when the planet has more, smaller cells.
var _object_scale := 1.0

## Terrain id -> hex color overriding terrains.json (player palette).
var palette: Dictionary = {}
## Draws a darker border around each land cell (easier to tell cells apart).
var outlines := true


func setup(p_planet, p_terrain_defs: Dictionary, p_camera: Camera3D, world_seed: int) -> void:
	planet = p_planet
	terrain_defs = p_terrain_defs
	camera = p_camera
	_world_seed = world_seed
	_object_scale = clampf(6.0 / float(planet.grid.frequency), 0.3, 1.2)
	# Smaller cells: let the camera come closer.
	_zoom_min = 1.2 + 3.2 / float(planet.grid.frequency)
	_compute_heights()
	_build_surface(world_seed)
	_placement = MeshInstance3D.new()
	_placement.material_override = _placement_material()
	_placement.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_placement.visible = false
	add_child(_placement)
	_buildings_root = Node3D.new()
	add_child(_buildings_root)
	refresh_buildings()
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
		if event.relative.length() > 2.0:
			rotated.emit()
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
	_zoom_target = clampf(value, _zoom_min, ZOOM_MAX)
	zoomed.emit()


func _update_camera() -> void:
	if camera == null:
		return
	# Far away the planet sits a bit low (room for the title); close up, centered.
	var t := clampf((_zoom - _zoom_min) / (ZOOM_MAX - _zoom_min), 0.0, 1.0)
	camera.position = Vector3(0.0, 0.25 * t, _zoom)


## Turns the planet so that `cell` faces the camera.
func focus_cell(cell: int) -> void:
	if cell < 0:
		return
	var target := Vector3(0.0, 0.3, 1.0).normalized()
	basis = Basis(Quaternion(planet.grid.centers[cell], target))
	_angular_velocity = Vector2.ZERO


## Rebuilds building models (and trees, which make room for buildings).
func refresh_buildings() -> void:
	for child in _buildings_root.get_children():
		child.queue_free()
	for cell in planet.cell_count():
		var id: String = planet.buildings[cell]
		if id == "":
			continue
		var node := BuildingMeshes.create(id)
		var dir: Vector3 = planet.grid.centers[cell]
		var top := _heights[cell] + float(_def(cell).get("peak", 0.0))
		var orient := Basis(Quaternion(Vector3.UP, dir)) * Basis.from_scale(Vector3.ONE * _object_scale)
		node.transform = Transform3D(orient, dir * top)
		_buildings_root.add_child(node)
	if _trees:
		_trees.queue_free()
		_trees = null
	_build_trees(_world_seed)
	if selected >= 0:
		_highlight.mesh = _build_highlight_mesh(selected)


## Rebuilds the ground (after a palette or outline change).
func rebuild_surface() -> void:
	for node in _surface_nodes:
		node.queue_free()
	_surface_nodes.clear()
	_build_surface(_world_seed)


func set_clouds_visible(value: bool) -> void:
	if _clouds:
		_clouds.visible = value


## Lights up the cells where the chosen building can go.
func set_placement(cells: Array) -> void:
	var buffer := MeshBuffer.new()
	var green := Color(0.36, 0.86, 0.74)  # Soft turquoise (design system TEAL).
	for cell in cells:
		var center: Vector3 = planet.grid.centers[cell]
		var cs: PackedVector3Array = planet.grid.corners[cell]
		var h := _heights[cell] + float(_def(cell).get("peak", 0.0)) + 0.006
		for k in cs.size():
			var a := center.lerp(cs[k], 0.82).normalized() * (_heights[cell] + 0.006)
			var b := center.lerp(cs[(k + 1) % cs.size()], 0.82).normalized() * (_heights[cell] + 0.006)
			buffer.add_tri(center * h, a, b, green, green, green, center)
	_placement.mesh = buffer.to_mesh(null)
	_placement.visible = not cells.is_empty()


func clear_placement() -> void:
	_placement.visible = false


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
		var color := Color(str(palette.get(planet.terrain[i], def.get("color", "ff00ff")))).darkened(tint * 0.09)
		var peak_color := Color(str(def.get("peak_color", color.to_html(false))))
		var center: Vector3 = grid.centers[i]
		var cs: PackedVector3Array = grid.corners[i]
		var top := center * (h + peak)
		var count := cs.size()
		var border := outlines and not is_water
		var edge_color := color.darkened(0.28)
		for k in count:
			var c0 := cs[k]
			var c1 := cs[(k + 1) % count]
			if border:
				# Inner polygon + thin darker ring along the edges.
				var i0 := center.lerp(c0, 0.9).normalized() * (h + peak * 0.1)
				var i1 := center.lerp(c1, 0.9).normalized() * (h + peak * 0.1)
				buffer.add_tri(top, i0, i1, peak_color, color, color, center)
				buffer.add_tri(i0, c0 * h, c1 * h, edge_color, edge_color, edge_color, center)
				buffer.add_tri(i0, c1 * h, i1, edge_color, edge_color, edge_color, center)
			else:
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
	_surface_nodes.append(instance)


## Toy-like trees: round canopies in forests and plains, little pines on the
## hills. Three MultiMeshes (trunks, canopies, pines) = three draw calls.
func _build_trees(world_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 31
	var trunks: Array[Transform3D] = []
	var canopies: Array[Transform3D] = []
	var canopy_colors: Array[Color] = []
	var pines: Array[Transform3D] = []
	var pine_colors: Array[Color] = []
	var grid = planet.grid
	for i in planet.cell_count():
		var amount := 0
		var is_pine := false
		match planet.terrain[i]:
			"forest":
				amount = rng.randi_range(4, 6)
			"plains":
				amount = 1 if rng.randf() < 0.3 else 0
			"hills":
				amount = 1 if rng.randf() < 0.45 else 0
				is_pine = true
		var cs: PackedVector3Array = grid.corners[i]
		var has_building: bool = planet.buildings.size() > i and planet.buildings[i] != ""
		for t in amount:
			var corner := cs[rng.randi() % cs.size()]
			var dir: Vector3 = (grid.centers[i] as Vector3).lerp(corner, rng.randf_range(0.15, 0.6)).normalized()
			var s := rng.randf_range(0.8, 1.3) * _object_scale
			var up := Basis(Quaternion(Vector3.UP, dir))
			var tint := rng.randf()
			if has_building:
				continue  # Same random draws either way: other trees stay in place.
			var ground := dir * _heights[i]
			trunks.append(Transform3D(up * Basis.from_scale(Vector3.ONE * s), ground + dir * 0.006 * s))
			if is_pine:
				pines.append(Transform3D(up * Basis.from_scale(Vector3.ONE * s), ground + dir * 0.022 * s))
				pine_colors.append(Color("4f9a6a").lerp(Color("6fb586"), tint))
			else:
				canopies.append(Transform3D(up * Basis.from_scale(Vector3.ONE * s), ground + dir * 0.02 * s))
				canopy_colors.append(Color("6cc070").lerp(Color("a6d96a"), tint))
	_trees = Node3D.new()
	add_child(_trees)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.0022
	trunk.bottom_radius = 0.003
	trunk.height = 0.012
	trunk.radial_segments = 5
	trunk.rings = 1
	var no_colors: Array[Color] = []
	_add_multimesh(trunk, trunks, no_colors, Color("9a6a45"))
	var canopy := SphereMesh.new()
	canopy.radius = 0.011
	canopy.height = 0.02
	canopy.radial_segments = 8
	canopy.rings = 4
	_add_multimesh(canopy, canopies, canopy_colors, Color.WHITE)
	var pine := CylinderMesh.new()
	pine.top_radius = 0.0
	pine.bottom_radius = 0.01
	pine.height = 0.03
	pine.radial_segments = 6
	pine.rings = 1
	pine.cap_top = false
	_add_multimesh(pine, pines, pine_colors, Color.WHITE)


func _add_multimesh(mesh: PrimitiveMesh, transforms: Array[Transform3D], colors: Array[Color], base: Color) -> void:
	if transforms.is_empty():
		return
	var mat := StandardMaterial3D.new()
	mat.roughness = 1.0
	mat.albedo_color = base
	mat.vertex_color_use_as_albedo = not colors.is_empty()
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for k in transforms.size():
		mm.set_instance_transform(k, transforms[k])
		if not colors.is_empty():
			mm.set_instance_color(k, colors[k])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trees.add_child(instance)


## Fluffy clouds: each one is 3 puffs of different sizes (one MultiMesh).
func _build_clouds(world_seed: int) -> Node3D:
	var pivot := Node3D.new()
	var puff := SphereMesh.new()
	puff.radius = 0.05
	puff.height = 0.085
	puff.radial_segments = 10
	puff.rings = 5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.99, 0.97)
	mat.roughness = 1.0
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.97, 0.93)
	mat.emission_energy_multiplier = 0.25  # Stay soft and bright on the night side.
	puff.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = puff
	mm.instance_count = CLOUD_COUNT * 3
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 1
	for i in CLOUD_COUNT:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.7, 0.7), rng.randf_range(-1, 1)).normalized()
		var orient := Basis.looking_at(dir).rotated(dir, rng.randf() * TAU)
		var size := rng.randf_range(0.8, 1.3)
		for p in 3:
			var offset := orient.x * (float(p) - 1.0) * 0.06 * size
			var puff_scale := size * (1.25 if p == 1 else 0.85)
			var puff_basis := orient * Basis.from_scale(Vector3(puff_scale, puff_scale * 0.8, puff_scale))
			mm.set_instance_transform(i * 3 + p, Transform3D(puff_basis, dir * 1.2 + offset))
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


func _placement_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 1, 1, 0.42)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 1
	return mat


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
