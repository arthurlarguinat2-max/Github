## Renders the hexagonal planet and handles touch controls:
##   - 1 finger drag: spin the planet (with inertia),
##   - pinch / mouse wheel: zoom,
##   - tap: select a cell (emits cell_selected).
## Rendering only: it reads the PlanetState but never changes game rules.
extends Node3D

signal cell_selected(cell: int)
signal villager_tapped
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
const TerrainBuilder := preload("res://scripts/render/terrain_builder.gd")
const Life := preload("res://scripts/render/life.gd")
const SURFACE_NOISE := preload("res://assets/terrain/surface_noise.tres")

var planet          # PlanetState
var economy         # Economy: construction sites and town hall level
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
var _caravan: Node3D
var _buildings_root: Node3D
var _world_seed := 0
var _surface_nodes: Array[Node] = []
var _placement: MeshInstance3D
## Objects (trees, buildings) shrink when the planet has more, smaller cells.
var _object_scale := 1.0
## Smooth terrain sampler (heights and colors anywhere on the planet).
var terrain := TerrainBuilder.new()
var _life: Node3D

## Terrain id -> hex color overriding terrains.json (player palette).
var palette: Dictionary = {}


func setup(p_planet, p_terrain_defs: Dictionary, p_camera: Camera3D, world_seed: int) -> void:
	planet = p_planet
	terrain_defs = p_terrain_defs
	camera = p_camera
	_world_seed = world_seed
	_object_scale = clampf(7.5 / float(planet.grid.frequency), 0.35, 1.2)
	# Smaller cells: let the camera come closer.
	_zoom_min = 1.14 + 2.8 / float(planet.grid.frequency)
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
	_clouds = _build_clouds()
	add_child(_clouds)
	_life = Life.new()
	add_child(_life)
	_life.setup(self)
	_highlight = MeshInstance3D.new()
	_highlight.material_override = _highlight_material()
	_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_highlight)
	_update_camera()


func _process(delta: float) -> void:
	if _caravan != null:
		_caravan.visible = economy.caravan_present()
	if _touches.is_empty() and _angular_velocity.length_squared() > 1e-6:
		_apply_rotation(_angular_velocity * delta)
		_angular_velocity *= exp(-INERTIA_DAMPING * delta)
	_clouds.rotate_y(delta * 0.009)
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


## Far away: the whole planet, a bit low on screen. Close up: the camera
## comes down and tilts (like a strategy game) to see the village from the
## side, with the planet's horizon at the top of the screen.
func _update_camera() -> void:
	if camera == null:
		return
	var t := clampf((_zoom - _zoom_min) / (ZOOM_MAX - _zoom_min), 0.0, 1.0)
	var close := pow(1.0 - t, 1.5)
	var target := Vector3(0.0, 0.25 * t, 0.0).lerp(Vector3(0.0, 0.0, 1.0), 1.0 - t)
	var tilt := deg_to_rad(48.0) * close
	var distance := lerpf(_zoom - 1.0, _zoom, t)
	camera.position = target + Vector3(0.0, -sin(tilt), cos(tilt)) * distance
	camera.look_at(target, Vector3.UP)
	if _clouds:
		_clouds.visible = _clouds_enabled and t > 0.25


## Turns the planet so that `cell` faces the camera.
func focus_cell(cell: int) -> void:
	if cell < 0:
		return
	var target := Vector3(0.0, -0.08, 1.0).normalized()
	basis = Basis(Quaternion(planet.grid.centers[cell], target))
	_angular_velocity = Vector2.ZERO


## Rebuilds building models (and trees, which make room for buildings).
func refresh_buildings() -> void:
	_caravan = null
	for child in _buildings_root.get_children():
		child.queue_free()
	for cell in planet.cell_count():
		var id: String = planet.buildings[cell]
		if id == "":
			continue
		var node: Node3D
		if economy != null and not economy.is_active(cell):
			node = BuildingMeshes.scaffold()
		else:
			node = BuildingMeshes.create(id, economy.townhall_level if economy != null else 1)
		if id == "market" and economy != null and economy.is_active(cell):
			_caravan = BuildingMeshes.caravan()
			_caravan.visible = economy.caravan_present()
			node.add_child(_caravan)
		var dir: Vector3 = planet.grid.centers[cell]
		var top := _heights[cell]
		var yaw := float(posmod(hash(cell * 31 + _world_seed), 628)) / 100.0
		var orient := Basis(Quaternion(Vector3.UP, dir)) * Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * _object_scale)
		node.transform = Transform3D(orient, dir * top)
		_buildings_root.add_child(node)
	if _trees:
		_trees.queue_free()
		_trees = null
	_build_trees(_world_seed)
	if selected >= 0:
		_highlight.mesh = _build_highlight_mesh(selected)


## Rebuilds the ground (after a palette change).
func rebuild_surface() -> void:
	for node in _surface_nodes:
		node.queue_free()
	_surface_nodes.clear()
	_compute_heights()
	_build_surface(_world_seed)


var _clouds_enabled := true


func set_clouds_visible(value: bool) -> void:
	_clouds_enabled = value
	if _clouds:
		_clouds.visible = value
	_update_camera()


## Lights up the cells where the chosen building can go.
func set_placement(cells: Array) -> void:
	var buffer := MeshBuffer.new()
	var green := Color(0.36, 0.86, 0.74)  # Soft turquoise (design system TEAL).
	for cell in cells:
		_add_marker(buffer, cell, 0.19, green, 16)
	_placement.mesh = buffer.to_mesh(null)
	_placement.visible = not cells.is_empty()


func clear_placement() -> void:
	_placement.visible = false


# --- Selection ---------------------------------------------------------------

func _select_at(screen_pos: Vector2) -> void:
	if not _placement.visible and _life.walker_at(screen_pos, camera):
		villager_tapped.emit()
		return
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
	terrain.setup(planet, terrain_defs, palette, _world_seed)
	_heights.resize(planet.cell_count())
	for i in planet.cell_count():
		_heights[i] = terrain.cell_top(i)


## Smooth land + animated sea.
func _build_surface(_seed: int) -> void:
	var subdivisions := 5 if planet.grid.frequency <= 12 else 6
	var land := terrain.build_land_mesh(subdivisions)
	_add_mesh(land)
	# Both surfaces use the same triangles, so depth and surf follow the coastline.
	var sea := MeshInstance3D.new()
	var water := ShaderMaterial.new()
	water.shader = preload("res://assets/terrain/sea.gdshader")
	var shallow := Color(str(palette.get("shallow", terrain_defs.get("shallow", {}).get("color", "86d0e0"))))
	var deep := Color(str(palette.get("ocean", terrain_defs.get("ocean", {}).get("color", "5aa9d6"))))
	water.set_shader_parameter("shallow_color", shallow)
	water.set_shader_parameter("deep_color", deep)
	sea.mesh = land
	sea.material_override = water
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	_surface_nodes.append(sea)


func _add_mesh(mesh: Mesh) -> void:
	if mesh == null:
		return
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	# The solid globe occludes light from the opposite hemisphere.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(instance)
	_surface_nodes.append(instance)


## Vegetation and details, all in MultiMeshes (one draw call per kind):
## leafy trees made of 2-3 round puffs (they sway in the wind), layered pines,
## rounded boulders on hills and mountains, little flowers on the plains.
func _build_trees(world_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 31
	var trunks: Array[Transform3D] = []
	var puffs: Array[Transform3D] = []
	var puff_colors: Array[Color] = []
	var pines: Array[Transform3D] = []
	var pine_colors: Array[Color] = []
	var rocks: Array[Transform3D] = []
	var rock_colors: Array[Color] = []
	var grasses: Array[Transform3D] = []
	var grass_colors: Array[Color] = []
	var flowers: Array[Transform3D] = []
	var flower_colors: Array[Color] = []
	var flower_palette := [Color("ff9ec2"), Color("ffe17a"), Color("ffffff"), Color("c9a7ff"), Color("ff8a7a")]
	var grid = planet.grid
	for i in planet.cell_count():
		var terrain_id: String = planet.terrain[i]
		var trees := 0
		var is_pine := false
		var stones := 0
		var blooms := 0
		match terrain_id:
			"forest":
				trees = rng.randi_range(4, 6)
			"plains":
				trees = 1 if rng.randf() < 0.3 else 0
				blooms = rng.randi_range(0, 4)
			"hills":
				trees = 1 if rng.randf() < 0.45 else 0
				is_pine = true
				stones = rng.randi_range(0, 2)
			"mountain":
				stones = rng.randi_range(2, 4)
			"desert":
				stones = 1 if rng.randf() < 0.35 else 0
			"beach":
				stones = 1 if rng.randf() < 0.2 else 0
		var cs: PackedVector3Array = grid.corners[i]
		var free_cell: bool = not (planet.buildings.size() > i and planet.buildings[i] != "")
		var center: Vector3 = grid.centers[i]
		for t in trees:
			var dir := _scatter(rng, center, cs, 0.15, 0.65)
			var s := rng.randf_range(0.76, 1.55) * _object_scale
			var up := Basis(Quaternion(Vector3.UP, dir)) * Basis(Vector3.UP, rng.randf() * TAU)
			var tint := rng.randf()
			var crown_count := rng.randi_range(2, 3)
			if not free_cell:
				continue  # Same random draws either way: other trees stay in place.
			var ground := dir * terrain.surface_radius(dir, i)
			trunks.append(Transform3D(up * Basis.from_scale(Vector3(1.0, 1.0 + 0.3 * tint, 1.0) * s), ground + dir * 0.006 * s))
			if is_pine or (absf(dir.y) > 0.45 and tint < 0.72):
				for layer in 3:
					var k := 1.0 - 0.28 * layer
					pines.append(Transform3D(up * Basis.from_scale(Vector3.ONE * s * k), ground + dir * (0.014 + 0.009 * layer) * s))
					pine_colors.append(Color("264d45").lerp(Color("63816a"), tint * 0.7 + 0.1 * layer))
			else:
				var base := Color("325541").lerp(Color("859657"), tint)
				var offsets := [Vector3(0, 0.02, 0), Vector3(0.006, 0.015, 0.003), Vector3(-0.005, 0.016, -0.004)]
				for p in crown_count:
					var o: Vector3 = offsets[p]
					var k := 1.0 if p == 0 else 0.7
					puffs.append(Transform3D(up * Basis.from_scale(Vector3(1.1, 1.22 - 0.32 * tint, 0.84) * s * k), ground + up * (o * s)))
					puff_colors.append(base.lightened(0.06 * p))
		for r in stones:
			var dir := _scatter(rng, center, cs, 0.1, 0.8)
			var size := rng.randf_range(0.6, 1.4) * _object_scale
			var squash := Vector3(rng.randf_range(0.9, 1.4), rng.randf_range(0.55, 0.85), rng.randf_range(0.8, 1.2)) * size
			var orient := Basis(Quaternion(Vector3.UP, dir)) * Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(squash)
			var grey := rng.randf()
			if not free_cell:
				continue
			rocks.append(Transform3D(orient, dir * (terrain.surface_radius(dir, i) + 0.002 * size)))
			rock_colors.append(Color("b3aba2").lerp(Color("8f877e"), grey))
		for f in blooms:
			var dir := _scatter(rng, center, cs, 0.1, 0.85)
			var pick: Color = flower_palette[rng.randi() % flower_palette.size()]
			if not free_cell:
				continue
			var ground := dir * terrain.surface_radius(dir, i)
			var tangent := Basis(Quaternion(Vector3.UP, dir)) * Basis(Vector3.UP, f * 2.4 + i)
			grasses.append(Transform3D(tangent.scaled_local(Vector3.ONE * _object_scale), ground))
			grass_colors.append(Color("72783e").lerp(Color("9aaf67"), float(f) / 4.0))
			flowers.append(Transform3D(tangent.scaled_local(Vector3.ONE * _object_scale), ground + dir * 0.005 * _object_scale))
			flower_colors.append(pick)
	_trees = Node3D.new()
	add_child(_trees)
	var no_colors: Array[Color] = []
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.0018
	trunk.bottom_radius = 0.003
	trunk.height = 0.014
	trunk.radial_segments = 12
	trunk.rings = 1
	_add_multimesh(trunk, trunks, no_colors, Color("9a6a45"))
	var puff := SphereMesh.new()
	puff.radius = 0.0095
	puff.height = 0.018
	puff.radial_segments = 10
	puff.rings = 6
	_add_multimesh(puff, puffs, puff_colors, Color.WHITE, true)
	# Overlapping tapered crowns give the conifers a soft silhouette from any angle.
	var profile := Curve.new()
	profile.add_point(Vector2(0.0, 0.02))
	profile.add_point(Vector2(0.18, 0.90))
	profile.add_point(Vector2(0.36, 0.98))
	profile.add_point(Vector2(0.70, 0.48))
	profile.add_point(Vector2(1.0, 0.02))
	var pine_surface := SurfaceTool.new()
	pine_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 12
	for level in 6:
		for side in sides:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var t := float(level + corner.y) / 6.0
				var angle := TAU * (side + corner.x) / sides
				var radial := Vector3(cos(angle), 0, sin(angle))
				var slope := (profile.sample_baked(minf(t + 0.02, 1.0)) - profile.sample_baked(maxf(t - 0.02, 0.0))) / 0.04
				pine_surface.set_normal((radial - Vector3.UP * slope * 0.625).normalized())
				pine_surface.add_vertex(radial * profile.sample_baked(t) * 0.010 + Vector3.UP * (t - 0.5) * 0.016)
	var pine := pine_surface.commit()
	_add_multimesh(pine, pines, pine_colors, Color.WHITE, true)
	var rock := SphereMesh.new()
	rock.radius = 0.006
	rock.height = 0.012
	rock.radial_segments = 12
	rock.rings = 4
	_add_multimesh(rock, rocks, rock_colors, Color.WHITE)
	_add_multimesh(_grass_tuft(), grasses, grass_colors, Color.WHITE, true, false)
	var bloom := SphereMesh.new()
	bloom.radius = 0.0016
	bloom.height = 0.0032
	bloom.radial_segments = 5
	bloom.rings = 3
	_add_multimesh(bloom, flowers, flower_colors, Color.WHITE, false, false)


## Six tapered blades share a single mesh across all meadow patches.
func _grass_tuft() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 6:
		var angle := float(blade) * 2.4
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var side := direction.cross(Vector3.UP) * 0.0016
		var base := direction * 0.002
		var tip := direction * 0.007 + Vector3.UP * (0.005 + 0.001 * (blade % 3))
		for point in [base - side, tip, base + side, base + side, tip, base - side]:
			surface.set_normal((Vector3.UP + direction * 0.5).normalized())
			surface.add_vertex(point)
	return surface.commit()


## Random point inside a cell, between `inner` and `outer` (0 = center).
func _scatter(rng: RandomNumberGenerator, center: Vector3, corners: PackedVector3Array, inner: float, outer: float) -> Vector3:
	var a := corners[rng.randi() % corners.size()]
	var b := corners[rng.randi() % corners.size()]
	var edge := a.lerp(b, rng.randf())
	return center.lerp(edge, rng.randf_range(inner, outer)).normalized()


## Leaves sway gently: each instance moves with its own phase.
const SWAY_SHADER := """
shader_type spatial;
render_mode specular_disabled;
varying vec3 leaf;
void vertex() {
	float phase = float(INSTANCE_ID) * 1.7;
	float crown = sin(VERTEX.x * 590.0 + phase) * cos(VERTEX.z * 510.0 - phase);
	VERTEX += NORMAL * crown * 0.0012;
	float lift = clamp(VERTEX.y / 0.009 + 1.0, 0.0, 2.0);
	VERTEX.x += sin(TIME * 1.6 + phase) * 0.0011 * lift;
	VERTEX.z += cos(TIME * 1.3 + phase) * 0.0008 * lift;
	leaf = COLOR.rgb * (0.74 + 0.17 * lift + 0.08 * crown);
}
void fragment() {
	ALBEDO = leaf;
	ROUGHNESS = 1.0;
}
"""


func _add_multimesh(mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color], base: Color, sway: bool = false, casts_shadow: bool = true) -> void:
	if transforms.is_empty():
		return
	var material: Material
	if sway and not colors.is_empty():
		var shader := Shader.new()
		shader.code = SWAY_SHADER
		var sway_mat := ShaderMaterial.new()
		sway_mat.shader = shader
		material = sway_mat
	else:
		var mat := StandardMaterial3D.new()
		mat.roughness = 1.0
		mat.albedo_color = base
		mat.vertex_color_use_as_albedo = not colors.is_empty()
		material = mat
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
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trees.add_child(instance)


## One slowly drifting cloud deck, with gaps to keep the surface readable.
func _build_clouds() -> Node3D:
	var shell := SphereMesh.new()
	shell.radius = 1.115
	shell.height = shell.radius * 2.0
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/terrain/clouds.gdshader")
	mat.set_shader_parameter("grain", SURFACE_NOISE)
	shell.material = mat
	var deck := MeshInstance3D.new()
	deck.mesh = shell
	deck.rotation.y = float(posmod(_world_seed, 360)) * PI / 180.0
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return deck


## Circular terrain-following markers leave the underlying landscape unobstructed.
func _build_highlight_mesh(cell: int) -> ArrayMesh:
	var buffer := MeshBuffer.new()
	_add_marker(buffer, cell, 0.43, Color.WHITE, 40)
	return buffer.to_mesh(null)


func _add_marker(buffer: MeshBuffer, cell: int, size: float, color: Color, segments: int) -> void:
	var center: Vector3 = planet.grid.centers[cell]
	var frame := Basis(Quaternion(Vector3.UP, center))
	var radius: float = terrain.spacing * size
	var first_outer := Vector3.ZERO
	var first_inner := Vector3.ZERO
	var prev_outer := Vector3.ZERO
	var prev_inner := Vector3.ZERO
	for step in range(segments + 1):
		var outer := first_outer
		var inner := first_inner
		if step < segments:
			var angle := TAU * step / segments
			var rim := frame * Vector3(cos(angle), 0, sin(angle)) * radius
			var a := (center + rim).normalized()
			var b := (center + rim * 0.86).normalized()
			outer = a * (maxf(terrain.surface_radius(a, cell), 1.0) + 0.005)
			inner = b * (maxf(terrain.surface_radius(b, cell), 1.0) + 0.005)
		if step == 0:
			first_outer = outer
			first_inner = inner
		else:
			buffer.add_tri(prev_outer, outer, inner, color, color, color, center)
			buffer.add_tri(prev_outer, inner, prev_inner, color, color, color, center)
		prev_outer = outer
		prev_inner = inner


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
