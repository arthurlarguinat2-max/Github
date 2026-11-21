# Mini Planète — CODE_2_RENDU_ET_INTERFACE

Rendu 3D (planète, bâtiments, vie), interface (HUD, menus, design) et scène principale.

Version du jeu : 0.6.x — 12 fichiers. Chaque fichier commence par une ligne « ### FICHIER : chemin ». Pour modifier un fichier, renvoie-le EN ENTIER avec son chemin.

## Sommaire
- scenes/main.tscn
- scripts/dev/screenshot_runner.gd
- scripts/main.gd
- scripts/platform/haptics.gd
- scripts/render/building_meshes.gd
- scripts/render/life.gd
- scripts/render/planet_view.gd
- scripts/render/terrain_builder.gd
- scripts/ui/design.gd
- scripts/ui/hud.gd
- scripts/ui/start_menu.gd
- scripts/ui/ui_kit.gd


### FICHIER : scenes/main.tscn

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/main.gd" id="1_main"]

[node name="Main" type="Node3D"]
script = ExtResource("1_main")
```


### FICHIER : scripts/dev/screenshot_runner.gd

```gdscript
## Development helper: takes screenshots of key screens, then quits.
## Only active when the game is started with:  -- --screenshot-dir=<folder>
## Used by CI (.github/workflows/screenshots.yml) to check the visual design.
extends Node

var hud
var planet
var out_dir := ""
var _frame := 0
const SHOTS := [
	[90, "1_accueil", "start"],
	[180, "2_jeu", "game"],
	[240, "3_construire", "build"],
	[300, "4_besoins", "needs"],
	[360, "5_reglages", "settings"],
	[420, "6_objectifs", "goals"],
	[500, "7_village_zoom", "closeup"],
	[580, "8_planete", "wide"],
]


func _process(_delta: float) -> void:
	_frame += 1
	for shot in SHOTS:
		if _frame == int(shot[0]) - 30:
			_prepare(str(shot[2]))
		if _frame == int(shot[0]):
			_capture(str(shot[1]))
	if _frame > int(SHOTS[-1][0]) + 5:
		get_tree().quit()


func _prepare(state: String) -> void:
	hud._close_sheets()
	match state:
		"start":
			hud._start_menu.open("main")
		"game":
			hud._start_menu.visible = false
		"build":
			hud._open_build_sheet(-1)
		"needs":
			hud._toggle_needs_sheet()
		"settings":
			hud._on_settings_pressed()
		"goals":
			hud._on_goals_pressed()
		"closeup":
			GameState.sim.tutorial_step = -1
			hud._refresh_tutorial()
			_build_demo_village()
			planet.focus_cell(GameState.sim.economy.village_center)
			planet._zoom = planet._zoom_min + 0.15
			planet._zoom_target = planet._zoom
			planet._update_camera()
		"wide":
			planet._zoom = 3.2
			planet._zoom_target = 3.2
			planet._update_camera()


## Places a few finished buildings around the town hall so the close-up
## shows them (screenshots only; never saved).
func _build_demo_village() -> void:
	var eco = GameState.sim.economy
	for res in ["wood", "stone", "food"]:
		eco.stocks[res] = 999.0
	eco.population = 12
	eco.townhall_level = 3
	eco._rebuild_caches()
	for id in ["hut", "well", "gatherer", "woodcutter", "field", "bakery", "hut", "campfire"]:
		for i in GameState.sim.planet.cell_count():
			var reason: String = eco.can_build(i, id)
			if reason == "" or reason == "BUILD_ERR_BUILDERS":
				GameState.sim.planet.buildings[i] = id
				eco._rebuild_caches()
				break
	eco.changed.emit()
	GameState.set_process(false)  # Freeze the demo state (and never autosave it).


func _capture(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var image := get_viewport().get_texture().get_image()
	image.save_png(out_dir.path_join(name + ".png"))
	print("screenshot: ", name)
```


### FICHIER : scripts/main.gd

```gdscript
## Main scene: assembles the 3D world (planet, sun, sky, camera) and the HUD,
## and applies the player's customization. Built in code to keep the .tscn
## minimal and merge-friendly.
extends Node3D

const PlanetView := preload("res://scripts/render/planet_view.gd")
const BuildingMeshes := preload("res://scripts/render/building_meshes.gd")
const Hud := preload("res://scripts/ui/hud.gd")

const STAR_COUNT := 320

var planet: PlanetView
var sun_pivot: Node3D
var sun: DirectionalLight3D
var hud: Hud
var _env: Environment
var _stars: MultiMeshInstance3D
var _star_material: StandardMaterial3D
var _rings: MeshInstance3D
var _sky_material: ProceduralSkyMaterial
var _atmosphere_material: ShaderMaterial

## Soft glow around the planet (fresnel rim), tinted by the sky.
const ATMOSPHERE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
uniform vec4 glow_color : source_color = vec4(1.0, 0.9, 0.8, 1.0);
uniform float strength = 0.9;
void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = glow_color.rgb;
	ALPHA = pow(rim, 2.6) * strength;
}
"""
var _moon_pivot: Node3D


func _ready() -> void:
	_build_environment()
	_build_stars()
	var cam := _build_camera()
	_build_sun()
	_build_decorations()
	hud = Hud.new()
	add_child(hud)

	var sim = GameState.sim
	planet = PlanetView.new()
	planet.economy = sim.economy
	add_child(planet)
	apply_appearance(false)  # Palette/outlines must be known before the first build.
	planet.setup(sim.planet, sim.terrain_defs, cam, sim.world_seed)
	apply_appearance(false)
	planet.focus_cell(sim.economy.village_center)
	planet.ui_blocks_point = hud.blocks_point
	planet.cell_selected.connect(hud.on_cell_tapped)
	planet.selection_cleared.connect(hud.hide_cell)
	sim.economy.changed.connect(planet.refresh_buildings)
	hud.close_requested.connect(planet.clear_selection)
	hud.placement_started.connect(planet.set_placement)
	hud.placement_ended.connect(planet.clear_placement)
	hud.appearance_changed.connect(apply_appearance.bind(true))
	planet.rotated.connect(hud.on_planet_rotated)
	_maybe_start_screenshots()
	planet.zoomed.connect(hud.on_planet_zoomed)


func _process(delta: float) -> void:
	# Day/night: the sun orbits the planet following the simulated time of day,
	# smoothed by the stepper's interpolation alpha.
	var sim = GameState.sim
	var t: float = sim.time_of_day() + GameState.stepper.interpolation_alpha() / float(sim.ticks_per_day)
	sun_pivot.rotation.y = t * TAU
	_moon_pivot.rotate_y(delta * 0.05)


## CI only: "-- --screenshot-dir=<folder>" captures the main screens and quits.
func _maybe_start_screenshots() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot-dir="):
			var runner = load("res://scripts/dev/screenshot_runner.gd").new()
			runner.hud = hud
			runner.planet = planet
			runner.out_dir = arg.trim_prefix("--screenshot-dir=")
			add_child(runner)


## Applies the planet customization (palette, village color) and the device
## preferences (sky, clouds, outlines). `rebuild` regenerates the ground mesh.
func apply_appearance(rebuild: bool) -> void:
	var custom: Dictionary = GameState.sim.custom
	var options: Dictionary = GameState.config.get("customization", {})
	var palettes: Dictionary = options.get("palettes", {})
	planet.palette = palettes.get(custom.get("palette", "classic"), {}).get("colors", {})
	planet.outlines = bool(UserSettings.get_value("outlines"))
	if rebuild:
		planet.rebuild_surface()
	planet.set_clouds_visible(bool(UserSettings.get_value("clouds")))
	BuildingMeshes.set_accent(Color(str(custom.get("village_color", "d9b45c"))))
	var skies: Dictionary = options.get("skies", {})
	var sky: Dictionary = skies.get(str(UserSettings.get_value("sky")), skies.get("soft", {}))
	var top := Color(str(sky.get("top", "8ecae6")))
	var horizon := Color(str(sky.get("horizon", "ffe3cf")))
	_sky_material.sky_top_color = top
	_sky_material.sky_horizon_color = horizon
	_sky_material.ground_horizon_color = horizon
	_sky_material.ground_bottom_color = Color(str(sky.get("bottom", "fff1e2")))
	_env.ambient_light_color = Color(str(sky.get("ambient", "f3e6ff")))
	sun.light_color = Color(str(sky.get("sun", "fff0d6")))
	_atmosphere_material.set_shader_parameter("glow_color", horizon.lerp(Color.WHITE, 0.35))
	var star_strength := float(sky.get("stars", 0.0))
	_stars.visible = star_strength > 0.0
	_star_material.albedo_color = Color(1, 1, 1, star_strength)
	_rings.visible = bool(custom.get("rings", false))
	_moon_pivot.visible = bool(custom.get("moon", true))


## Diorama look: a soft gradient sky instead of black space, pastel ambient
## light so the night side stays gentle, and a linear tonemap that keeps the
## pastel colors as designed.
func _build_environment() -> void:
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_curve = 0.12
	_sky_material.ground_curve = 0.08
	_sky_material.sun_angle_max = 0.0
	_sky_material.sky_energy_multiplier = 1.0
	var sky := Sky.new()
	sky.sky_material = _sky_material
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_energy = 0.62
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

	# Atmosphere halo, slightly larger than the planet.
	var halo := SphereMesh.new()
	halo.radius = 1.16
	halo.height = 2.32
	halo.radial_segments = 48
	halo.rings = 24
	_atmosphere_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = ATMOSPHERE_SHADER
	_atmosphere_material.shader = shader
	halo.material = _atmosphere_material
	var halo_instance := MeshInstance3D.new()
	halo_instance.mesh = halo
	halo_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo_instance)


## Distant stars: tiny unshaded spheres in one MultiMesh (a single draw call).
func _build_stars() -> void:
	var dot := SphereMesh.new()
	dot.radius = 0.09
	dot.height = 0.18
	dot.radial_segments = 4
	dot.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	dot.material = mat
	_star_material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = dot
	mm.instance_count = STAR_COUNT
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in STAR_COUNT:
		var dir := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var size := rng.randf_range(0.5, 1.6)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size), dir * 45.0))
		var warmth := rng.randf()
		mm.set_instance_color(i, Color(1.0, 0.92 + 0.08 * warmth, 0.85 + 0.15 * (1.0 - warmth), rng.randf_range(0.4, 1.0)))
	_stars = MultiMeshInstance3D.new()
	_stars.multimesh = mm
	_stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_stars)


## Optional planetary rings and a small moon (cosmetic, chosen in Settings).
func _build_decorations() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 1.45
	torus.outer_radius = 1.9
	torus.rings = 48
	torus.ring_segments = 3
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.86, 0.8, 0.66, 0.55)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_mat.roughness = 1.0
	torus.material = ring_mat
	_rings = MeshInstance3D.new()
	_rings.mesh = torus
	_rings.scale = Vector3(1.0, 0.03, 1.0)
	_rings.rotation = Vector3(deg_to_rad(18), 0, deg_to_rad(-8))
	_rings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rings)

	_moon_pivot = Node3D.new()
	_moon_pivot.rotation = Vector3(deg_to_rad(12), 0, 0)
	add_child(_moon_pivot)
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = 0.16
	moon_mesh.height = 0.32
	moon_mesh.radial_segments = 10
	moon_mesh.rings = 6
	var moon_mat := StandardMaterial3D.new()
	moon_mat.albedo_color = Color(0.78, 0.78, 0.8)
	moon_mat.roughness = 1.0
	moon_mesh.material = moon_mat
	var moon := MeshInstance3D.new()
	moon.mesh = moon_mesh
	moon.position = Vector3(2.6, 0.5, -1.2)
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_moon_pivot.add_child(moon)


func _build_camera() -> Camera3D:
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH  # Portrait: fit the planet to the width.
	cam.fov = 42.0
	cam.near = 0.02
	cam.far = 120.0
	add_child(cam)
	cam.current = true
	return cam


func _build_sun() -> void:
	sun_pivot = Node3D.new()
	add_child(sun_pivot)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.94, 0.84)  # Warm golden light.
	sun.light_energy = 0.95
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY  # No sun disc in the gradient sky.
	sun.shadow_enabled = false  # Shadows are costly on mobile.
	sun_pivot.add_child(sun)
	# Tilted sun so the terminator line crosses the planet nicely.
	sun.rotation = Vector3(deg_to_rad(-20), deg_to_rad(-60), 0)
```


### FICHIER : scripts/platform/haptics.gd

```gdscript
## Light haptic feedback wrapper. On iOS, Input.vibrate_handheld() uses the
## Taptic Engine (duration + amplitude). Safe no-op on desktop.
extends RefCounted

static var enabled := true


static func light() -> void:
	_vibrate(10, 0.3)


static func medium() -> void:
	_vibrate(20, 0.6)


static func _vibrate(duration_ms: int, amplitude: float) -> void:
	if enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms, amplitude)
```


### FICHIER : scripts/render/building_meshes.gd

```gdscript
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
```


### FICHIER : scripts/render/life.gd

```gdscript
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
```


### FICHIER : scripts/render/planet_view.gd

```gdscript
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
const TerrainBuilder := preload("res://scripts/render/terrain_builder.gd")
const Life := preload("res://scripts/render/life.gd")
const CLOUD_COUNT := 18

## Sea sphere: gentle swell, sparkles, bright rim; slightly see-through so
## sandy shallows show under the water.
const WATER_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;
uniform vec3 shallow_color : source_color = vec3(0.53, 0.82, 0.88);
uniform vec3 deep_color : source_color = vec3(0.35, 0.66, 0.84);
varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
	float swell = sin(TIME * 1.1 + VERTEX.x * 40.0 + VERTEX.z * 31.0) * sin(TIME * 0.8 + VERTEX.y * 37.0);
	VERTEX += NORMAL * swell * 0.0012;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float sparkle = sin(TIME * 1.7 + local_pos.x * 90.0) * sin(TIME * 1.3 + local_pos.z * 80.0);
	vec3 water = mix(deep_color, shallow_color, 0.45 + 0.12 * sparkle);
	ALBEDO = mix(water, vec3(1.0), rim * 0.35);
	ALPHA = 0.76 + rim * 0.2;
	ROUGHNESS = 0.16;
	SPECULAR = 0.8;
}
"""

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
## Draws a darker border around each land cell (easier to tell cells apart).
var outlines := true


func setup(p_planet, p_terrain_defs: Dictionary, p_camera: Camera3D, world_seed: int) -> void:
	planet = p_planet
	terrain_defs = p_terrain_defs
	camera = p_camera
	_world_seed = world_seed
	_object_scale = clampf(7.5 / float(planet.grid.frequency), 0.35, 1.2)
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
	_life = Life.new()
	add_child(_life)
	_life.setup(self)
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


## Rebuilds the ground (after a palette or outline change).
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
		var center: Vector3 = planet.grid.centers[cell]
		var cs: PackedVector3Array = planet.grid.corners[cell]
		var h := _heights[cell] + 0.006
		for k in cs.size():
			var da := center.lerp(cs[k], 0.82).normalized()
			var db := center.lerp(cs[(k + 1) % cs.size()], 0.82).normalized()
			var a := da * (maxf(terrain.surface_radius(da, cell), 1.0) + 0.006)
			var b := db * (maxf(terrain.surface_radius(db, cell), 1.0) + 0.006)
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
	terrain.setup(planet, terrain_defs, palette, _world_seed)
	_heights.resize(planet.cell_count())
	for i in planet.cell_count():
		_heights[i] = terrain.cell_top(i)


## Smooth land + animated sea + optional thin cell outlines.
func _build_surface(_seed: int) -> void:
	var subdivisions := 5 if planet.grid.frequency <= 12 else 6
	_add_mesh(terrain.build_land_mesh(subdivisions))
	var sea := SphereMesh.new()
	sea.radius = TerrainBuilder.SEA_LEVEL
	sea.height = TerrainBuilder.SEA_LEVEL * 2.0
	sea.radial_segments = 96
	sea.rings = 48
	var water := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = WATER_SHADER
	water.shader = shader
	var shallow := Color(str(palette.get("shallow", terrain_defs.get("shallow", {}).get("color", "86d0e0"))))
	var deep := Color(str(palette.get("ocean", terrain_defs.get("ocean", {}).get("color", "5aa9d6"))))
	water.set_shader_parameter("shallow_color", shallow)
	water.set_shader_parameter("deep_color", deep)
	sea.material = water
	_add_mesh(sea)
	if outlines:
		_add_mesh(terrain.build_outline_mesh())


func _add_mesh(mesh: Mesh) -> void:
	if mesh == null:
		return
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
			var s := rng.randf_range(0.8, 1.3) * _object_scale
			var up := Basis(Quaternion(Vector3.UP, dir)) * Basis(Vector3.UP, rng.randf() * TAU)
			var tint := rng.randf()
			if not free_cell:
				continue  # Same random draws either way: other trees stay in place.
			var ground := dir * terrain.surface_radius(dir, i)
			trunks.append(Transform3D(up * Basis.from_scale(Vector3(1.0, 1.0 + 0.3 * tint, 1.0) * s), ground + dir * 0.006 * s))
			if is_pine:
				for layer in 3:
					var k := 1.0 - 0.28 * layer
					pines.append(Transform3D(up * Basis.from_scale(Vector3.ONE * s * k), ground + dir * (0.014 + 0.009 * layer) * s))
					pine_colors.append(Color("4f9a6a").lerp(Color("78bd8c"), tint * 0.7 + 0.1 * layer))
			else:
				var base := Color("6cc070").lerp(Color("a6d96a"), tint)
				var offsets := [Vector3(0, 0.02, 0), Vector3(0.006, 0.015, 0.003), Vector3(-0.005, 0.016, -0.004)]
				for p in rng.randi_range(2, 3):
					var o: Vector3 = offsets[p]
					var k := 1.0 if p == 0 else 0.7
					puffs.append(Transform3D(up * Basis.from_scale(Vector3.ONE * s * k), ground + up * (o * s)))
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
			flowers.append(Transform3D(Basis.from_scale(Vector3.ONE * _object_scale), dir * (terrain.surface_radius(dir, i) + 0.0015)))
			flower_colors.append(pick)
	_trees = Node3D.new()
	add_child(_trees)
	var no_colors: Array[Color] = []
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.0018
	trunk.bottom_radius = 0.003
	trunk.height = 0.014
	trunk.radial_segments = 6
	trunk.rings = 1
	_add_multimesh(trunk, trunks, no_colors, Color("9a6a45"))
	var puff := SphereMesh.new()
	puff.radius = 0.0095
	puff.height = 0.018
	puff.radial_segments = 10
	puff.rings = 6
	_add_multimesh(puff, puffs, puff_colors, Color.WHITE, true)
	var pine := CylinderMesh.new()
	pine.top_radius = 0.0
	pine.bottom_radius = 0.01
	pine.height = 0.016
	pine.radial_segments = 8
	pine.rings = 1
	_add_multimesh(pine, pines, pine_colors, Color.WHITE, true)
	var rock := SphereMesh.new()
	rock.radius = 0.006
	rock.height = 0.012
	rock.radial_segments = 7
	rock.rings = 4
	_add_multimesh(rock, rocks, rock_colors, Color.WHITE)
	var bloom := SphereMesh.new()
	bloom.radius = 0.0016
	bloom.height = 0.0032
	bloom.radial_segments = 5
	bloom.rings = 3
	_add_multimesh(bloom, flowers, flower_colors, Color.WHITE)


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
	float lift = clamp(VERTEX.y / 0.009 + 1.0, 0.0, 2.0);
	VERTEX.x += sin(TIME * 1.6 + phase) * 0.0011 * lift;
	VERTEX.z += cos(TIME * 1.3 + phase) * 0.0008 * lift;
	leaf = COLOR.rgb;
}
void fragment() {
	ALBEDO = leaf;
	ROUGHNESS = 1.0;
}
"""


func _add_multimesh(mesh: PrimitiveMesh, transforms: Array[Transform3D], colors: Array[Color], base: Color, sway: bool = false) -> void:
	if transforms.is_empty():
		return
	if sway and not colors.is_empty():
		var shader := Shader.new()
		shader.code = SWAY_SHADER
		var sway_mat := ShaderMaterial.new()
		sway_mat.shader = shader
		mesh.material = sway_mat
	else:
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


## Bright ring along the border of the selected cell, following the terrain.
func _build_highlight_mesh(cell: int) -> ArrayMesh:
	var buffer := MeshBuffer.new()
	var center: Vector3 = planet.grid.centers[cell]
	var cs: PackedVector3Array = planet.grid.corners[cell]
	var white := Color.WHITE
	for k in cs.size():
		var da: Vector3 = cs[k]
		var db: Vector3 = cs[(k + 1) % cs.size()]
		var ia := center.lerp(da, 0.8).normalized()
		var ib := center.lerp(db, 0.8).normalized()
		var a := da * (maxf(terrain.surface_radius(da, cell), 1.0) + 0.005)
		var b := db * (maxf(terrain.surface_radius(db, cell), 1.0) + 0.005)
		var a_in := ia * (maxf(terrain.surface_radius(ia, cell), 1.0) + 0.005)
		var b_in := ib * (maxf(terrain.surface_radius(ib, cell), 1.0) + 0.005)
		buffer.add_tri(a, b, b_in, white, white, white, center)
		buffer.add_tri(a, b_in, a_in, white, white, white, center)
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
```


### FICHIER : scripts/render/terrain_builder.gd

```gdscript
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
	if _peaks[c] > 0.0:
		var d := clampf(1.0 - dir.angle_to(grid.centers[c]) / (spacing * 1.05), 0.0, 1.0)
		var bump := d * d * (3.0 - 2.0 * d)
		h += _peaks[c] * bump
		color = color.lerp(_peak_colors[c], clampf(bump * 1.4 - 0.3, 0.0, 1.0))
	if h > SEA_LEVEL:
		h += _noise.get_noise_3dv(dir * 6.0) * NOISE_AMPLITUDE
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
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.92
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
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
			var a_in := a.lerp(center * a.length(), 0.07)
			var b_in := b.lerp(center * b.length(), 0.07)
			positions.append_array(PackedVector3Array([a, b, b_in, a, b_in, a_in]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.98, 0.92, 0.17)
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
```


### FICHIER : scripts/ui/design.gd

```gdscript
## "Diorama doux" design system: one place for colors, fonts and styles.
## Warm cream panels, brown ink, coral accent, soft shadows, rounded type.
## Change the look of the whole game from here.
extends RefCounted

# --- Palette ---------------------------------------------------------------------
const CREAM := Color("fff6e9")        # Sheets and cards
const CREAM_DEEP := Color("f6e8d4")   # Secondary surfaces
const CARD := Color("fffdf8")         # Chips, buttons
const INK := Color("4a3b2f")          # Main text
const INK_SOFT := Color("8a7564")     # Secondary text
const INK_FAINT := Color("b8a898")    # Disabled text
const CORAL := Color("f2786a")        # Primary action
const CORAL_DARK := Color("d95f52")
const CORAL_SOFT := Color("ffd9cf")   # Selected toggle
const TEAL := Color("5bb5a2")         # Positive / progress
const TEAL_SOFT := Color("dff3ec")
const SKY_SOFT := Color("e6f2fb")     # Tutorial card
const PARCHMENT := Color("fff0dc")    # Events
const SUN := Color("ffc857")
const GOOD := Color("3f9e6e")
const BAD := Color("d9534f")
const WARN := Color("d9822b")
const SHADOW := Color(0.35, 0.22, 0.1, 0.16)
const WHITE := Color.WHITE

# Same colors as hex, for BBCode in rich text.
const HEX_GOOD := "#3f9e6e"
const HEX_BAD := "#d9534f"
const HEX_SOFT := "#8a7564"

static var _title_font: Font
static var _body_font: Font


## Rounded system font for titles and buttons (no font file to license).
static func title_font() -> Font:
	if _title_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Arial Rounded MT Bold", "Avenir Next", "Helvetica Neue"])
		f.font_weight = 700
		_title_font = f
	return _title_font


static func body_font() -> Font:
	if _body_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue"])
		f.font_weight = 500
		_body_font = f
	return _body_font


## Rounded panel with an optional soft drop shadow.
static func panel(color: Color, radius: int = 20, margin: int = 12, shadow: bool = true) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	style.anti_aliasing = true
	if shadow:
		style.shadow_color = SHADOW
		style.shadow_size = 8
		style.shadow_offset = Vector2(0, 3)
	return style


## Panel with a colored outline (selected states, focus).
static func outlined(color: Color, border: Color, radius: int = 16, margin: int = 8) -> StyleBoxFlat:
	var style := panel(color, radius, margin, false)
	style.set_border_width_all(3)
	style.border_color = border
	return style


## Styles a button as the main action (coral, white text).
static func make_primary(button: Button, radius: int = 18) -> void:
	button.add_theme_stylebox_override("normal", panel(CORAL, radius, 8))
	button.add_theme_stylebox_override("hover", panel(CORAL.lightened(0.06), radius, 8))
	button.add_theme_stylebox_override("pressed", panel(CORAL_DARK, radius, 8))
	button.add_theme_stylebox_override("hover_pressed", panel(CORAL_DARK, radius, 8))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, WHITE)
	button.add_theme_font_override("font", title_font())


## The whole UI theme: buttons, toggles, text fields, progress bars, labels.
static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = body_font()
	theme.default_font_size = 16
	var normal := panel(CARD, 16, 8)
	var hover := panel(Color("fff3e0"), 16, 8)
	var pressed := outlined(CORAL_SOFT, CORAL, 16, 8)
	var disabled := panel(Color("efe6da"), 16, 8, false)
	for type in ["Button", "CheckButton"]:
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("hover_pressed", type, pressed)
		theme.set_stylebox("disabled", type, disabled)
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
		theme.set_color("font_color", type, INK)
		theme.set_color("font_hover_color", type, INK)
		theme.set_color("font_pressed_color", type, INK)
		theme.set_color("font_hover_pressed_color", type, INK)
		theme.set_color("font_focus_color", type, INK)
		theme.set_color("font_disabled_color", type, INK_FAINT)
		theme.set_color("icon_normal_color", type, WHITE)
		theme.set_color("icon_disabled_color", type, Color(1, 1, 1, 0.45))
		theme.set_font("font", type, title_font())
	theme.set_stylebox("normal", "LineEdit", panel(WHITE, 14, 10, false))
	theme.set_stylebox("focus", "LineEdit", outlined(WHITE, CORAL, 14, 10))
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", INK_FAINT)
	theme.set_color("caret_color", "LineEdit", CORAL)
	theme.set_color("font_color", "Label", INK)
	theme.set_color("default_color", "RichTextLabel", INK)
	var track := panel(Color("efe2cf"), 6, 0, false)
	var fill := panel(TEAL, 6, 0, false)
	theme.set_stylebox("background", "ProgressBar", track)
	theme.set_stylebox("fill", "ProgressBar", fill)
	return theme
```


### FICHIER : scripts/ui/hud.gd

```gdscript
## Game interface, designed to be simple and thumb-friendly:
##   top    : planet name + day, resource chips with icons,
##   bottom : 4 big buttons (pause, speed, build, settings),
##   sheets : build menu, cell card, settings (one at a time).
## Building is 2 taps: pick a building, then a green cell on the planet.
extends CanvasLayer

signal close_requested
signal placement_started(cells: Array)
signal placement_ended
signal appearance_changed

const Haptics := preload("res://scripts/platform/haptics.gd")
const Economy := preload("res://scripts/simulation/economy.gd")
const UiKit := preload("res://scripts/ui/ui_kit.gd")
const Design := preload("res://scripts/ui/design.gd")
const StartMenu := preload("res://scripts/ui/start_menu.gd")
const Objectives := preload("res://scripts/simulation/objectives.gd")
const Events := preload("res://scripts/simulation/events.gd")
const ICON_DIR := "res://assets/icons/ui/"

const BASE_PADDING := 14.0
const REFRESH_INTERVAL := 0.25
# Colors come from the design system (scripts/ui/design.gd).
const TEXT := Design.INK
const MUTED := Design.INK_SOFT
const WARN := Design.WARN
const GOOD := Design.GOOD
const BAD := Design.BAD
const PANEL_BG := Design.CREAM
const SPEEDS := [1, 2, 4]

var _margin: MarginContainer
var _title: Label
var _chips := {}           # resource -> {"value": Label, "rate": Label}
var _toast: Label
var _toast_tween: Tween
var _hint: Label
var _pause_button: Button
var _speed_button: Button
var _build_button: Button
var _settings_button: Button
var _bottom_bar: Control

# Sheets (only one visible at a time).
var _sheets: Array[Control] = []
var _build_sheet: PanelContainer
var _build_sheet_title: Label
var _build_list: VBoxContainer
var _cell_card: PanelContainer
var _cell_title: Label
var _cell_text: Label
var _cell_build_button: Button
var _demolish_button: Button
var _settings_sheet: PanelContainer
var _needs_sheet: PanelContainer
var _needs_text: RichTextLabel
var _needs_row: PanelContainer
var _category_buttons := {}  # category id -> Button
var _category := "housing"
var _banner: PanelContainer
var _banner_label: Label

var _cell := -1             # Cell shown in the card.
var _target_cell := -1      # Build menu opened from a cell ("build here").
var _placing := ""          # Building being placed (2-tap flow).
var _confirm_demolish := false
var _confirm_new_world := false
var _new_world_size := 8
var _last_speed := 1
var _refresh_timer := 0.0
var _blocking: Array[Control] = []

# Tutorial, goals, events, start screen.
var _tutorial_panel: PanelContainer
var _tutorial_text: Label
var _tutorial_count: Label
var _tutorial_next: Button
var _tutorial_steps: Array = []
var _tutorial_flags := {}
var _pulse_tween: Tween
var _pulsing: Control
var _goals_button: Button
var _goals_sheet: PanelContainer
var _goals_list: VBoxContainer
var _event_sheet: PanelContainer
var _event_title: Label
var _event_text: Label
var _event_choices: VBoxContainer
var _upgrade_button: Button
var _start_menu: Control
var _settings_tab := "planet"
var _village_tab := "townhall"
var _village_signature := ""


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	_margin.add_child(column)

	_title = _label("", 18, TEXT)
	_title.add_theme_font_override("font", Design.title_font())
	column.add_child(_title)
	column.add_child(_build_chip_row(["food", "water", "wood", "stone"]))
	_needs_row = _build_needs_row()
	column.add_child(_needs_row)
	_toast = _label("", 15, TEXT)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_stylebox_override("normal", Design.panel(Color("fff3c4"), 18, 10))
	_toast.visible = false
	column.add_child(_toast)
	_tutorial_panel = _build_tutorial_panel()
	column.add_child(_tutorial_panel)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	_banner = _build_banner()
	column.add_child(_banner)
	_build_sheet = _build_build_sheet()
	column.add_child(_build_sheet)
	_cell_card = _build_cell_card()
	column.add_child(_cell_card)
	_settings_sheet = _build_settings_sheet()
	column.add_child(_settings_sheet)
	_needs_sheet = _build_needs_sheet()
	column.add_child(_needs_sheet)
	_goals_sheet = _build_goals_sheet()
	column.add_child(_goals_sheet)
	_event_sheet = _build_event_sheet()
	column.add_child(_event_sheet)
	_sheets.append_array([_build_sheet, _cell_card, _settings_sheet, _needs_sheet, _goals_sheet, _event_sheet])

	_hint = _label(tr("HINT_DRAG"), 13, MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)
	_bottom_bar = _build_bottom_bar()
	column.add_child(_bottom_bar)

	_start_menu = StartMenu.new()
	root.add_child(_start_menu)
	_start_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_start_menu.tutorial_requested.connect(restart_tutorial)
	_start_menu.closed.connect(func(): GameState.start_menu_shown = true)
	_start_menu.visible = not GameState.start_menu_shown
	_start_menu.visibility_changed.connect(func(): _margin.visible = not _start_menu.visible)
	_margin.visible = not _start_menu.visible
	_blocking.append_array([_bottom_bar, _banner, _build_sheet, _cell_card, _settings_sheet, _needs_sheet, _needs_row,
		_tutorial_panel, _goals_sheet, _event_sheet, _start_menu])
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	GameState.ticked.connect(_refresh_title)
	GameState.sim.economy.alert.connect(_on_alert)
	GameState.sim.objective_completed.connect(_on_objective_completed)
	GameState.sim.economy.construction_done.connect(_on_construction_done)
	GameState.sim.economy.level_up.connect(_show_level_up)
	GameState.sim.economy.training_done.connect(_on_training_done)
	GameState.sim.event_started.connect(_show_event)
	var steps_file: Dictionary = GameState.config.get("tutorial", {})
	_tutorial_steps = steps_file.get("steps", [])
	_last_speed = GameState.sim.speed if GameState.sim.speed > 0 else 1
	_refresh_title()
	_refresh_chips()
	_refresh_speed_buttons()
	if GameState.pending_offline_days > 0:
		_show_toast(tr("OFFLINE_WELCOME") % GameState.pending_offline_days)
		GameState.pending_offline_days = 0
	_greet_new_version()
	_refresh_tutorial()
	if GameState.sim.pending_event != "":
		_show_event.call_deferred(GameState.sim.pending_event)


func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer < REFRESH_INTERVAL:
		return
	_refresh_timer = 0.0
	_refresh_chips()
	_check_tutorial()
	if _goals_sheet.visible:
		_update_goals_sheet()
	if _cell_card.visible:
		_update_cell_card()
	if _build_sheet.visible:
		_update_build_cards()
	if _needs_sheet.visible:
		_update_needs_sheet()


## True when `point` (viewport coordinates) is over an interactive UI element.
func blocks_point(point: Vector2) -> bool:
	for control in _blocking:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point):
			return true
	return false


# =============================================================================
# Top: title and resource chips
# =============================================================================

func _build_chip_row(resources: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for res in resources:
		row.add_child(_chip(res))
	return row


func _chip(res: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", Design.panel(Design.CARD, 16, 5))
	chip.clip_contents = true
	chip.custom_minimum_size = Vector2(40, 0)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(line)
	line.add_child(_icon(res, 20))
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", -4)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(texts)
	var value := _label("", 15, TEXT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(value)
	var rate := _label("", 10, MUTED)
	rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(rate)
	_chips[res] = {"value": value, "rate": rate}
	return chip


## Population, happiness and health. Tapping it opens the "needs" screen.
func _build_needs_row() -> PanelContainer:
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_toggle_needs_sheet())
	var row := _build_chip_row(["people", "happy", "health"])
	holder.add_child(row)
	return holder


func _refresh_chips() -> void:
	var eco = GameState.sim.economy
	for res in ["food", "water", "wood", "stone"]:
		var chip: Dictionary = _chips[res]
		var rate := float(eco.rates.get(res, 0.0))
		chip.value.text = str(floori(eco.stock(res)))
		chip.rate.text = (_format_signed(rate) + tr("PER_DAY")) if absf(rate) >= 0.05 else "—"
		chip.rate.add_theme_color_override("font_color", GOOD if rate > 0.05 else (BAD if rate < -0.05 else MUTED))
		var empty: bool = (res == "food" or res == "water") and eco.stock(res) <= 0.0
		chip.value.add_theme_color_override("font_color", BAD if empty else TEXT)
	var people: Dictionary = _chips["people"]
	people.value.text = "%d/%d" % [eco.population, eco.housing()]
	people.rate.text = tr("WORKERS_SHORT") % [eco.employed(), eco.jobs()]
	_set_gauge(_chips["happy"], eco.happiness, eco.target_of(eco.happiness_factors()))
	_set_gauge(_chips["health"], eco.health, eco.target_of(eco.health_factors()))


## Shows a 0-100 gauge and where it is heading.
func _set_gauge(chip: Dictionary, value: float, target: float) -> void:
	chip.value.text = "%d %%" % roundi(value)
	chip.value.add_theme_color_override("font_color", BAD if value < 30.0 else (WARN if value < 50.0 else TEXT))
	if target > value + 1.0:
		chip.rate.text = tr("TREND_UP")
		chip.rate.add_theme_color_override("font_color", GOOD)
	elif target < value - 1.0:
		chip.rate.text = tr("TREND_DOWN")
		chip.rate.add_theme_color_override("font_color", BAD)
	else:
		chip.rate.text = tr("TREND_STABLE")
		chip.rate.add_theme_color_override("font_color", MUTED)


func _refresh_title() -> void:
	_title.text = "%s · %s" % [GameState.sim.custom.get("planet_name", ""), tr("DAY_N") % GameState.sim.day()]


## After an update, says which version is now installed (once).
func _greet_new_version() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	var last := str(UserSettings.get_value("last_version"))
	if version == "" or version == last:
		return
	UserSettings.set_value("last_version", version)
	_show_toast(tr("UPDATE_INSTALLED") % version)


func _on_alert(key: String) -> void:
	_show_toast(tr(key))
	Haptics.medium()


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(4.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 1.0)
	_toast_tween.tween_callback(func(): _toast.visible = false)


# =============================================================================
# Bottom bar: pause, speed, build, settings
# =============================================================================

func _build_bottom_bar() -> PanelContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	_pause_button = _icon_button("pause", "", Vector2(48, 54))
	_pause_button.pressed.connect(_on_pause_pressed)
	bar.add_child(_pause_button)
	_speed_button = _icon_button("", "x1", Vector2(48, 54))
	_speed_button.pressed.connect(_on_speed_pressed)
	bar.add_child(_speed_button)
	_build_button = _icon_button("build", tr("BUILD"), Vector2(0, 54))
	_build_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Design.make_primary(_build_button, 22)
	_build_button.add_theme_font_size_override("font_size", 16)
	_build_button.add_theme_constant_override("icon_max_width", 22)
	_build_button.add_theme_constant_override("h_separation", 4)
	_build_button.pressed.connect(_on_build_pressed)
	bar.add_child(_build_button)
	_goals_button = _icon_button("townhall", "", Vector2(48, 54))
	_goals_button.pressed.connect(_on_goals_pressed)
	bar.add_child(_goals_button)
	_settings_button = _icon_button("settings", "", Vector2(48, 54))
	_settings_button.pressed.connect(_on_settings_pressed)
	bar.add_child(_settings_button)
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", Design.panel(Design.CREAM, 30, 6))
	pill.add_child(bar)
	return pill


func _on_pause_pressed() -> void:
	var sim = GameState.sim
	sim.set_speed(_last_speed if sim.speed == 0 else 0)
	Haptics.light()
	_refresh_speed_buttons()


func _on_speed_pressed() -> void:
	var index := SPEEDS.find(_last_speed)
	_last_speed = SPEEDS[(index + 1) % SPEEDS.size()]
	GameState.sim.set_speed(_last_speed)
	_tutorial_flags["speed"] = true
	Haptics.light()
	_refresh_speed_buttons()


func _refresh_speed_buttons() -> void:
	var paused: bool = GameState.sim.speed == 0
	_pause_button.icon = _texture("play" if paused else "pause")
	_speed_button.text = "x%d" % _last_speed
	_speed_button.modulate = Color(1, 1, 1, 0.5) if paused else Color.WHITE


func _on_build_pressed() -> void:
	if _placing != "":
		_end_placement()
		return
	if _build_sheet.visible:
		_close_sheets()
		return
	_open_build_sheet(-1)


func _on_settings_pressed() -> void:
	if _settings_sheet.visible:
		_close_sheets()
		return
	_end_placement()
	_confirm_new_world = false
	_refresh_settings_sheet()
	_show_sheet(_settings_sheet)
	close_requested.emit()


# =============================================================================
# Sheets
# =============================================================================

func _show_sheet(sheet: Control) -> void:
	for s in _sheets:
		s.visible = s == sheet
	_hint.visible = false
	_tutorial_panel.visible = not _current_step().is_empty() and (sheet == _build_sheet or sheet == _cell_card)


func _close_sheets() -> void:
	for s in _sheets:
		s.visible = false
	_hint.visible = _placing == ""
	_tutorial_panel.visible = not _current_step().is_empty()


func _sheet(title_label: Label) -> Array:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Design.panel(PANEL_BG, 28, 16))
	panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.add_theme_font_override("font", Design.title_font())
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title_label)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(44, 44)
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(func():
		_close_sheets()
		close_requested.emit())
	header.add_child(close)
	return [panel, box]


# --- Build menu ---------------------------------------------------------------

func _build_build_sheet() -> PanelContainer:
	_build_sheet_title = _label("", 20, TEXT)
	var parts := _sheet(_build_sheet_title)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	parts[1].add_child(tabs)
	var group := ButtonGroup.new()
	var categories: Array = GameState.config.get("building_categories", [])
	for cat in categories:
		var tab := Button.new()
		tab.toggle_mode = true
		tab.button_group = group
		tab.text = tr(str(cat.name_key))
		tab.custom_minimum_size = Vector2(0, 40)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.clip_text = true
		tab.add_theme_font_size_override("font_size", 12)
		tab.add_theme_stylebox_override("normal", Design.panel(Design.CARD, 14, 3))
		tab.add_theme_stylebox_override("hover", Design.panel(Design.CARD, 14, 3))
		tab.add_theme_stylebox_override("pressed", Design.outlined(Design.CORAL_SOFT, Design.CORAL, 14, 3))
		tab.add_theme_stylebox_override("hover_pressed", Design.outlined(Design.CORAL_SOFT, Design.CORAL, 14, 3))
		tab.pressed.connect(func():
			_category = str(cat.id)
			_open_build_sheet(_target_cell)
			Haptics.light())
		tabs.add_child(tab)
		_category_buttons[str(cat.id)] = tab
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 230)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts[1].add_child(scroll)
	_build_list = VBoxContainer.new()
	_build_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_build_list)
	return parts[0]


## Opens the build menu. With a cell: builds right there; without: 2-tap flow.
func _open_build_sheet(cell: int) -> void:
	_end_placement()
	_target_cell = cell
	_build_sheet_title.text = tr("BUILD_HERE") if cell >= 0 else tr("BUILD_WHAT")
	var eco_b = GameState.sim.economy
	if not eco_b.townhall_levels.is_empty():
		_build_sheet_title.text += "\n" + tr("BUILDERS_FREE") % [eco_b.free_builders(), eco_b.builders()]
	for child in _build_list.get_children():
		_build_list.remove_child(child)
		child.queue_free()
	var eco = GameState.sim.economy
	var ids: Array = eco.defs.keys()
	ids.sort_custom(func(a, b): return int(eco.defs[a].get("order", 99)) < int(eco.defs[b].get("order", 99)))
	for cat_id in _category_buttons:
		_category_buttons[cat_id].set_pressed_no_signal(cat_id == _category)
	for id in ids:
		if str(eco.defs[id].get("category", "housing")) != _category or not eco.defs[id].get("buildable", true):
			continue
		if cell >= 0 and eco.can_build(cell, id) in [Economy.ERR_TERRAIN, Economy.ERR_DEPOSIT]:
			continue
		_build_list.add_child(_build_card(id))
	_update_build_cards()
	_show_sheet(_build_sheet)


## A wide card: icon, name, short effect, cost.
func _build_card(id: String) -> Button:
	var bdef: Dictionary = GameState.sim.economy.defs[id]
	var card := Button.new()
	card.name = id
	card.custom_minimum_size = Vector2(0, 62)
	card.clip_text = true
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.icon = _texture(id)
	card.expand_icon = false
	card.add_theme_constant_override("icon_max_width", 40)
	card.add_theme_constant_override("h_separation", 12)
	card.text = _card_text(id, "")
	card.pressed.connect(_on_build_card_pressed.bind(id))
	return card


## Name and cost, then either the effect or why it can't be built yet.
func _card_text(id: String, reason: String) -> String:
	var eco = GameState.sim.economy
	var bdef: Dictionary = eco.defs[id]
	var second := tr(str(bdef.get("short_key", "")))
	if reason == Economy.ERR_LOCKED:
		second = tr("LOCKED_AT") % eco.unlock_level(id)
	elif reason == Economy.ERR_LIMIT:
		second = tr("LIMIT_REACHED") % [eco.building_count(id), eco.building_limit(id)]
	elif reason == Economy.ERR_BUILDERS:
		second = tr("BUILD_ERR_BUILDERS")
	elif not eco.townhall_levels.is_empty():
		second += "  (%d/%d)" % [eco.building_count(id), eco.building_limit(id)]
	return "%s  ·  %s\n%s" % [tr(str(bdef.get("name_key", id))), _cost_text(bdef.get("cost", {})), second]


func _update_build_cards() -> void:
	var eco = GameState.sim.economy
	for card in _build_list.get_children():
		var id := str(card.name)
		var reason := ""
		if eco.building_limit(id) <= 0:
			reason = Economy.ERR_LOCKED
		elif eco.building_count(id) >= eco.building_limit(id):
			reason = Economy.ERR_LIMIT
		elif float(eco.defs[id].get("build_days", 0.0)) > 0.0 and not eco.townhall_levels.is_empty() and eco.free_builders() <= 0:
			reason = Economy.ERR_BUILDERS
		elif _target_cell >= 0:
			reason = eco.can_build(_target_cell, id)
		elif not eco.can_afford(eco.defs[id].get("cost", {})):
			reason = Economy.ERR_COST
		(card as Button).disabled = reason != ""
		(card as Button).text = _card_text(id, reason)


func _on_build_card_pressed(id: String) -> void:
	var eco = GameState.sim.economy
	if _target_cell >= 0:
		if eco.build(_target_cell, id):
			Haptics.medium()
			GameState.sim.check_objectives()
			_show_toast(tr("BUILT") % tr(str(eco.defs[id].get("name_key", id))))
		_close_sheets()
		close_requested.emit()
		return
	var cells := _valid_cells(id)
	if cells.is_empty():
		_show_toast(tr("BUILD_NO_SPOT"))
		return
	_placing = id
	_close_sheets()
	_banner_label.text = tr("PLACE_HINT") % tr(str(eco.defs[id].get("name_key", id)))
	_banner.visible = true
	_hint.visible = false
	close_requested.emit()
	placement_started.emit(cells)
	Haptics.light()


func _valid_cells(id: String) -> Array:
	var eco = GameState.sim.economy
	var cells: Array = []
	for i in GameState.sim.planet.cell_count():
		if eco.can_build(i, id) == "":
			cells.append(i)
	return cells


func _build_banner() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Design.panel(Design.TEAL_SOFT, 20, 12))
	panel.visible = false
	var row := HBoxContainer.new()
	panel.add_child(row)
	_banner_label = _label("", 15, TEXT)
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_banner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_banner_label)
	var cancel := Button.new()
	cancel.text = tr("CANCEL")
	cancel.custom_minimum_size = Vector2(0, 44)
	cancel.pressed.connect(_end_placement)
	row.add_child(cancel)
	return panel


func _end_placement() -> void:
	if _placing == "":
		return
	_placing = ""
	_banner.visible = false
	_hint.visible = true
	placement_ended.emit()


# --- Cell card ----------------------------------------------------------------

## Called when the player taps a cell on the planet.
func on_cell_tapped(cell: int) -> void:
	if _placing != "":
		var eco = GameState.sim.economy
		var id := _placing
		var reason: String = eco.can_build(cell, id)
		if reason == "" and eco.build(cell, id):
			Haptics.medium()
			GameState.sim.check_objectives()
			_show_toast(tr("BUILT") % tr(str(eco.defs[id].get("name_key", id))))
			_end_placement()
		else:
			_show_toast(tr(reason))
		close_requested.emit()
		return
	_cell = cell
	_tutorial_flags["select"] = true
	_confirm_demolish = false
	_update_cell_card()
	_show_sheet(_cell_card)
	Haptics.light()


func hide_cell() -> void:
	if _cell_card.visible:
		_close_sheets()
	_cell = -1


func _build_cell_card() -> PanelContainer:
	_cell_title = _label("", 20, TEXT)
	var parts := _sheet(_cell_title)
	var box: VBoxContainer = parts[1]
	_cell_text = _label("", 15, MUTED)
	_cell_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_cell_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_cell_text)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	_cell_build_button = _icon_button("build", tr("BUILD_HERE"), Vector2(0, 50))
	_cell_build_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cell_build_button.pressed.connect(func():
		if _cell == GameState.sim.economy.village_center:
			_village_tab = "townhall"
			_on_goals_pressed()
		else:
			_open_build_sheet(_cell))
	actions.add_child(_cell_build_button)
	_upgrade_button = _icon_button("build", "", Vector2(0, 50))
	_upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	actions.add_child(_upgrade_button)
	_demolish_button = Button.new()
	_demolish_button.custom_minimum_size = Vector2(0, 50)
	_demolish_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_demolish_button.pressed.connect(_on_demolish_pressed)
	actions.add_child(_demolish_button)
	return parts[0]


func _update_cell_card() -> void:
	if _cell < 0:
		return
	var sim = GameState.sim
	var planet = sim.planet
	var eco = sim.economy
	var terrain_id: String = planet.terrain[_cell]
	var tdef: Dictionary = sim.terrain_defs.get(terrain_id, {})
	var building_id: String = planet.buildings[_cell]
	var lines := PackedStringArray()

	if building_id != "":
		var bdef: Dictionary = eco.defs.get(building_id, {})
		_cell_title.text = tr(str(bdef.get("name_key", building_id)))
		lines.append(_building_status(_cell, bdef))
		lines.append(tr(str(tdef.get("name_key", terrain_id))))
	else:
		_cell_title.text = tr(str(tdef.get("name_key", terrain_id)))
		if not tdef.get("water", false):
			lines.append(tr("CELL_FERTILITY") % roundi(planet.fertility[_cell] * 100.0))
		var found := _visible_resources(_cell)
		if not found.is_empty():
			lines.append(tr("CELL_RESOURCES") % " · ".join(found))

	var can_build_here: bool = building_id == "" and not tdef.get("water", false) and eco.in_territory(_cell)
	if building_id == "" and not tdef.get("water", false) and not eco.in_territory(_cell):
		lines.append(tr("BUILD_ERR_TERRITORY"))
	_cell_text.text = "\n".join(lines)
	_cell_build_button.visible = can_build_here or _cell == eco.village_center
	_cell_build_button.text = tr("OPEN_TOWNHALL") if _cell == eco.village_center else tr("BUILD_HERE")
	_demolish_button.visible = building_id != "" and _cell != eco.village_center
	var upgrade_id: String = eco.upgrade_target(_cell) if building_id != "" else ""
	_upgrade_button.visible = upgrade_id != ""
	if upgrade_id != "":
		_upgrade_button.text = tr("UPGRADE") % [tr(str(eco.defs[upgrade_id].get("name_key", upgrade_id))), _cost_text(eco.upgrade_cost(_cell))]
		_upgrade_button.disabled = eco.can_upgrade(_cell) != ""
	_demolish_button.text = tr("DEMOLISH_CONFIRM") if _confirm_demolish else tr("DEMOLISH")


## One clear line about what a building is doing right now.
func _building_status(cell: int, bdef: Dictionary) -> String:
	var eco = GameState.sim.economy
	if not eco.is_active(cell):
		return tr("BLD_UNDER_CONSTRUCTION") % [roundi(eco.construction_progress(cell) * 100.0), _format_days(eco.construction_left(cell))]
	if cell == eco.village_center:
		if eco.townhall_upgrade_left >= 0.0:
			return tr("TH_UPGRADING") % [eco.townhall_level + 1, _format_days(eco.townhall_upgrade_days_left())]
		return tr("BLD_TOWNHALL_STATUS") % [eco.townhall_level, eco.housing()]
	var housing := int(bdef.get("housing", 0))
	if housing > 0:
		return tr("BLD_HOUSING") % housing
	var need := int(bdef.get("workers", 0))
	if need > 0 and eco.workers_at(cell) == 0:
		var profession := str(bdef.get("profession", ""))
		if profession != "" and not eco.townhall_levels.is_empty():
			return tr("BLD_NEEDS_TRAINED") % tr(str(eco.professions.get(profession, {}).get("name_key", profession)))
		return tr("BLD_IDLE")
	if bdef.has("happiness") and not bdef.has("produces"):
		return tr("BLD_GIVES_HAPPINESS") % int(bdef.happiness)
	if bdef.has("health"):
		return tr("BLD_GIVES_HEALTH") % [int(bdef.health), eco.workers_at(cell), need]
	if bdef.has("produces"):
		if eco.is_waiting(cell):
			var inputs := PackedStringArray()
			for res in bdef.get("consumes", {}):
				inputs.append(tr(_res_key(res)).to_lower())
			return tr("BLD_WAITING") % " + ".join(inputs)
		if bdef.has("extracts") and not eco.has_deposit(cell, str(bdef.extracts)):
			return tr("BLD_DEPLETED")
		var rate: Dictionary = eco.building_rate(cell)
		var out := PackedStringArray()
		for res in bdef.produces:
			out.append("%s %s" % [_format_signed(float(rate.get(res, 0.0))), tr(_res_key(res)).to_lower()])
		return tr("BLD_STATUS") % [" · ".join(out), eco.workers_at(cell), need]
	return tr(str(bdef.get("short_key", "")))


func _visible_resources(cell: int) -> PackedStringArray:
	var found := PackedStringArray()
	var res_defs: Dictionary = GameState.config.get("resources", {})
	var cell_res: Dictionary = GameState.sim.planet.resources[cell]
	for res_id in cell_res:
		var res_def: Dictionary = res_defs.get(res_id, {})
		if res_def.get("hidden", false):
			continue  # Revealed by a later age.
		found.append("%s %d" % [tr(str(res_def.get("name_key", res_id))), floori(float(cell_res[res_id]))])
	return found


func _on_upgrade_pressed() -> void:
	if GameState.sim.economy.upgrade(_cell):
		Haptics.medium()
		_show_toast(tr("UPGRADED"))
		GameState.sim.check_objectives()
	_update_cell_card()


func _on_demolish_pressed() -> void:
	if not _confirm_demolish:
		_confirm_demolish = true
		_update_cell_card()
		return
	if GameState.sim.economy.demolish(_cell):
		Haptics.medium()
	_confirm_demolish = false
	_update_cell_card()


# --- Needs ------------------------------------------------------------------------

func _build_needs_sheet() -> PanelContainer:
	var parts := _sheet(_label(tr("NEEDS_TITLE"), 20, TEXT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 280)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts[1].add_child(scroll)
	_needs_text = RichTextLabel.new()
	_needs_text.bbcode_enabled = true
	_needs_text.fit_content = true
	_needs_text.scroll_active = false
	_needs_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_needs_text.add_theme_font_size_override("normal_font_size", 15)
	_needs_text.add_theme_font_size_override("bold_font_size", 16)
	scroll.add_child(_needs_text)
	return parts[0]


func _toggle_needs_sheet() -> void:
	if _needs_sheet.visible:
		_close_sheets()
		return
	_end_placement()
	_tutorial_flags["needs"] = true
	_update_needs_sheet()
	_show_sheet(_needs_sheet)
	close_requested.emit()
	Haptics.light()


## Plain-language summary: each need, its state, and what moves it.
func _update_needs_sheet() -> void:
	var eco = GameState.sim.economy
	var t := ""
	var food_rate := float(eco.rates.get("food", 0.0))
	var water_rate := float(eco.rates.get("water", 0.0))
	t += _need_line(tr("RES_FOOD"), food_rate >= 0.0 or eco.stock("food") > 0.0, tr("NEED_FOOD") % [floori(eco.stock("food")), _format_signed(food_rate)])
	t += _need_line(tr("RES_WATER"), water_rate >= 0.0 or eco.stock("water") > 0.0, tr("NEED_WATER") % [floori(eco.stock("water")), _format_signed(water_rate)])
	t += _need_line(tr("NEED_HOUSING"), eco.population <= eco.housing(), tr("NEED_HOUSING_TEXT") % [eco.population, eco.housing()])
	t += _need_line(tr("NEED_WORK"), eco.employed() >= eco.population * 0.6, tr("NEED_WORK_TEXT") % [eco.employed(), eco.jobs()])
	t += "\n[b]%s : %d %%[/b]  [color=#8a7564](%s)[/color]\n" % [tr("HAPPINESS"), roundi(eco.happiness), tr("NEED_PRODUCTIVITY") % roundi(eco.productivity() * 100.0)]
	t += _factor_lines(eco.happiness_factors())
	t += "\n[b]%s : %d %%[/b]\n" % [tr("HEALTH"), roundi(eco.health)]
	t += _factor_lines(eco.health_factors())
	t += "\n[b]%s[/b]\n" % tr("NEED_STOCKS")
	for res in ["grain", "flour", "tools"]:
		t += "%s : %d\n" % [tr(_res_key(res)), floori(eco.stock(res))]
	t += "\n[color=#8a7564]%s[/color]" % tr("NEED_TIP")
	_needs_text.text = t


func _need_line(title: String, ok: bool, text: String) -> String:
	var color := "%s" % Design.HEX_GOOD if ok else "%s" % Design.HEX_BAD
	return "[color=%s]•[/color] [b]%s[/b] — %s\n" % [color, title, text]


func _factor_lines(factors: Array) -> String:
	var out := ""
	for f in factors:
		var value := float(f[1])
		if str(f[0]) == "WB_BASE":
			out += "   %s %d\n" % [tr("WB_BASE"), roundi(value)]
			continue
		var color := "%s" % Design.HEX_GOOD if value > 0.0 else "%s" % Design.HEX_BAD
		out += "   [color=%s]%s%d[/color] %s\n" % [color, "+" if value > 0.0 else "", roundi(value), tr(str(f[0]))]
	return out


# --- Settings -----------------------------------------------------------------

func _build_settings_sheet() -> PanelContainer:
	var parts := _sheet(_label(tr("SETTINGS"), 20, TEXT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts[1].add_child(scroll)
	var box := VBoxContainer.new()
	box.name = "Content"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	return parts[0]


## Rebuilt each time the sheet opens, so it always shows current values.
## Three tabs keep it short: Planet, Display, Game.
func _refresh_settings_sheet() -> void:
	var box: VBoxContainer = _settings_sheet.find_child("Content", true, false)
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var sim = GameState.sim
	var options: Dictionary = GameState.config.get("customization", {})

	var tabs := {"planet": {"name_key": "SECTION_PLANET", "order": 0}, "display": {"name_key": "SECTION_DISPLAY", "order": 1}, "game": {"name_key": "SECTION_GAME", "order": 2}}
	box.add_child(UiKit.choice_grid(tabs, _settings_tab, func(id: String):
		_settings_tab = id
		_refresh_settings_sheet.call_deferred()))

	match _settings_tab:
		"planet":
			box.add_child(_caption(tr("PLANET_NAME")))
			var name_row := HBoxContainer.new()
			name_row.add_theme_constant_override("separation", 8)
			var name_edit := LineEdit.new()
			name_edit.text = str(sim.custom.get("planet_name", ""))
			name_edit.max_length = 18
			name_edit.custom_minimum_size = Vector2(0, 46)
			name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_edit.text_changed.connect(func(text: String):
				if text.strip_edges() != "":
					sim.custom["planet_name"] = text.strip_edges()
					_refresh_title())
			name_row.add_child(name_edit)
			var dice := _icon_button("dice", "", Vector2(46, 46))
			dice.pressed.connect(func():
				var new_name: String = sim.generate_name(randi(), sim.name_syllables)
				sim.custom["planet_name"] = new_name
				name_edit.text = new_name
				_refresh_title()
				Haptics.light())
			name_row.add_child(dice)
			box.add_child(name_row)
			box.add_child(_caption(tr("PALETTE")))
			box.add_child(UiKit.choice_grid(options.get("palettes", {}), str(sim.custom.get("palette", "classic")), func(id: String):
				sim.custom["palette"] = id
				appearance_changed.emit()
				Haptics.light()))
			box.add_child(_caption(tr("VILLAGE_COLOR")))
			box.add_child(UiKit.swatches(options.get("village_colors", []), str(sim.custom.get("village_color", "")), func(hex: String):
				sim.custom["village_color"] = hex
				appearance_changed.emit()
				Haptics.light()))
			box.add_child(_caption(tr("DECORATIONS")))
			for key in ["rings", "moon"]:
				var toggle := CheckButton.new()
				toggle.text = tr("DECOR_" + key.to_upper())
				toggle.icon = _texture(key)
				toggle.add_theme_constant_override("icon_max_width", 28)
				toggle.custom_minimum_size = Vector2(0, 44)
				toggle.button_pressed = bool(sim.custom.get(key, false))
				toggle.toggled.connect(func(on: bool):
					sim.custom[key] = on
					appearance_changed.emit())
				box.add_child(toggle)
		"display":
			box.add_child(_caption(tr("SKY")))
			box.add_child(UiKit.choice_grid(options.get("skies", {}), str(UserSettings.get_value("sky")), func(id: String):
				UserSettings.set_value("sky", id)
				appearance_changed.emit()
				Haptics.light()))
			box.add_child(_toggle(tr("CLOUDS"), "clouds", true))
			box.add_child(_toggle(tr("OUTLINES"), "outlines", true))
		"game":
			box.add_child(_toggle(tr("HAPTICS"), "haptics", false))
			box.add_child(_caption(tr("LANGUAGE")))
			var current_lang := str(UserSettings.get_value("language"))
			if current_lang == "":
				current_lang = TranslationServer.get_locale().substr(0, 2)
			box.add_child(UiKit.choice_grid({"fr": {"name_key": "LANG_FR", "order": 0}, "en": {"name_key": "LANG_EN", "order": 1}}, current_lang, func(id: String):
				UserSettings.set_value("language", id)
				GameState.save_game()
				get_tree().reload_current_scene()))
			var tuto := _icon_button("help", tr("START_TUTORIAL"), Vector2(0, 50))
			tuto.pressed.connect(func():
				_close_sheets()
				restart_tutorial())
			box.add_child(tuto)
			var new_planet := _icon_button("build", tr("START_NEW"), Vector2(0, 50))
			new_planet.pressed.connect(func():
				_close_sheets()
				_start_menu.open("new"))
			box.add_child(new_planet)
			var home := _icon_button("play", tr("START_SCREEN"), Vector2(0, 50))
			home.pressed.connect(func():
				_close_sheets()
				_start_menu.open("main"))
			box.add_child(home)
			box.add_child(_label(tr("VERSION") % ProjectSettings.get_setting("application/config/version", "?"), 11, Design.INK_FAINT))


func _section(text: String) -> Label:
	var label := _label(text, 16, TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label


func _caption(text: String) -> Label:
	var label := _label(text, 13, MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Toggle buttons (one choice) laid out on 2-3 columns.
func _choice_grid(choices: Dictionary, current: String, on_pick: Callable) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3 if choices.size() >= 3 else 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var ids: Array = choices.keys()
	ids.sort_custom(func(a, b): return int(choices[a].get("order", 0)) < int(choices[b].get("order", 0)))
	var group := ButtonGroup.new()
	for id in ids:
		var choice: Dictionary = choices[id]
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = tr(str(choice.get("name_key", id)))
		if choice.has("cells"):
			button.text += "\n" + tr("CELLS_N") % int(choice.cells)
		button.button_pressed = str(id) == current
		button.pressed.connect(func():
			on_pick.call(str(id))
			Haptics.light())
		grid.add_child(button)
	return grid


func _toggle(text: String, key: String, affects_view: bool) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.custom_minimum_size = Vector2(0, 44)
	toggle.button_pressed = bool(UserSettings.get_value(key))
	toggle.toggled.connect(func(on: bool):
		UserSettings.set_value(key, on)
		if affects_view:
			appearance_changed.emit())
	return toggle


# =============================================================================
# Tutorial
# =============================================================================

func _build_tutorial_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Design.panel(Design.SKY_SOFT, 20, 12))
	panel.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	row.add_child(_icon("help", 34))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	_tutorial_count = _label("", 11, MUTED)
	_tutorial_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(_tutorial_count)
	_tutorial_text = _label("", 15, TEXT)
	_tutorial_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_tutorial_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(_tutorial_text)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	texts.add_child(buttons)
	var skip := Button.new()
	skip.text = tr("TUTO_SKIP")
	skip.custom_minimum_size = Vector2(0, 38)
	skip.pressed.connect(func():
		GameState.sim.tutorial_step = -1
		_refresh_tutorial())
	buttons.add_child(skip)
	_tutorial_next = Button.new()
	_tutorial_next.text = tr("TUTO_NEXT")
	_tutorial_next.custom_minimum_size = Vector2(0, 38)
	_tutorial_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Design.make_primary(_tutorial_next, 14)
	_tutorial_next.pressed.connect(_advance_tutorial)
	buttons.add_child(_tutorial_next)
	return panel


func restart_tutorial() -> void:
	GameState.sim.tutorial_step = 0
	_tutorial_flags.clear()
	_refresh_tutorial()


func on_planet_rotated() -> void:
	_tutorial_flags["rotate"] = true


func on_planet_zoomed() -> void:
	_tutorial_flags["zoom"] = true


func _current_step() -> Dictionary:
	var index: int = GameState.sim.tutorial_step
	if index < 0 or index >= _tutorial_steps.size():
		return {}
	return _tutorial_steps[index]


func _refresh_tutorial() -> void:
	var step := _current_step()
	_stop_pulse()
	if step.is_empty():
		_tutorial_panel.visible = false
		if GameState.sim.tutorial_step >= _tutorial_steps.size():
			GameState.sim.tutorial_step = -1
		return
	_tutorial_panel.visible = true
	_tutorial_count.text = tr("TUTO_STEP") % [GameState.sim.tutorial_step + 1, _tutorial_steps.size()]
	var text := tr(str(step.get("text_key", "")))
	if text.contains("%s"):
		text = text % GameState.sim.custom.get("planet_name", "")
	_tutorial_text.text = text
	_tutorial_next.visible = str(step.get("condition", "")) == "next"
	match str(step.get("highlight", "")):
		"build":
			_start_pulse(_build_button)
		"needs":
			_start_pulse(_needs_row)
		"speed":
			_start_pulse(_speed_button)
		"goals", "village":
			_start_pulse(_goals_button)


func _advance_tutorial() -> void:
	GameState.sim.tutorial_step += 1
	_tutorial_flags.clear()
	Haptics.light()
	_refresh_tutorial()


## Moves to the next step as soon as its condition is met.
func _check_tutorial() -> void:
	var step := _current_step()
	if step.is_empty():
		return
	var condition := str(step.get("condition", "next"))
	var done := false
	if condition.begins_with("building:"):
		var parts := condition.split(":")
		done = GameState.sim.planet.buildings.count(parts[1]) >= int(parts[2])
	elif condition.begins_with("trained:"):
		var parts := condition.split(":")
		done = GameState.sim.economy.trained_count(parts[1]) >= int(parts[2])
	elif condition != "next":
		done = _tutorial_flags.get(condition, false)
	if done:
		_advance_tutorial()


func _start_pulse(control: Control) -> void:
	_pulsing = control
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(control, "modulate", Color(1.2, 1.05, 0.75), 0.5)
	_pulse_tween.tween_property(control, "modulate", Color.WHITE, 0.5)


func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	if _pulsing:
		_pulsing.modulate = Color.WHITE
		_pulsing = null


# =============================================================================
# Goals
# =============================================================================

func _on_goals_pressed() -> void:
	_tutorial_flags["goals"] = true
	_tutorial_flags["village"] = true
	if _goals_sheet.visible:
		_close_sheets()
		return
	_end_placement()
	_village_signature = ""
	_update_goals_sheet()
	_show_sheet(_goals_sheet)
	close_requested.emit()
	Haptics.light()


func _build_goals_sheet() -> PanelContainer:
	var parts := _sheet(_label(tr("VILLAGE_TITLE"), 20, TEXT))
	var tabs := {"townhall": {"name_key": "TAB_TOWNHALL", "order": 0}, "people": {"name_key": "TAB_PEOPLE", "order": 1}, "goals": {"name_key": "TAB_GOALS", "order": 2}}
	var tab_holder := VBoxContainer.new()
	tab_holder.name = "Tabs"
	parts[1].add_child(tab_holder)
	tab_holder.add_child(UiKit.choice_grid(tabs, _village_tab, func(id: String):
		_village_tab = id
		_village_signature = ""
		_update_goals_sheet()
		Haptics.light()))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts[1].add_child(scroll)
	_goals_list = VBoxContainer.new()
	_goals_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goals_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_goals_list)
	return parts[0]


## Rebuilt only when something visible changed (so buttons stay pressable).
func _update_goals_sheet() -> void:
	var eco = GameState.sim.economy
	var signature := str([_village_tab, eco.townhall_level, snappedf(eco.townhall_upgrade_left, 0.02), eco.trained,
		eco.training.size(), eco.population, floori(eco.stock("food")), floori(eco.stock("wood")), floori(eco.stock("stone")),
		GameState.sim.completed_objectives.size(), eco.free_builders()])
	if signature == _village_signature:
		return
	_village_signature = signature
	for child in _goals_list.get_children():
		_goals_list.remove_child(child)
		child.queue_free()
	match _village_tab:
		"townhall":
			_fill_townhall_tab()
		"people":
			_fill_people_tab()
		_:
			_fill_goals_tab()


func _fill_goals_tab() -> void:
	var sim = GameState.sim
	var shown := 0
	var done_count := 0
	for obj in sim.objective_defs:
		var done: bool = str(obj.id) in sim.completed_objectives
		if done:
			done_count += 1
	_goals_list.add_child(_caption(tr("GOALS_PROGRESS") % [done_count, sim.objective_defs.size()]))
	# Unfinished goals first (the next 5), then the completed ones.
	for pass_done in [false, true]:
		for obj in sim.objective_defs:
			var done: bool = str(obj.id) in sim.completed_objectives
			if done != pass_done or (not done and shown >= 5):
				continue
			if not done:
				shown += 1
			_goals_list.add_child(_goal_row(obj, done))


## Town hall: level, skills, next level (unlocks, conditions, cost), upgrade.
func _fill_townhall_tab() -> void:
	var eco = GameState.sim.economy
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(_icon("townhall", 48))
	var head_text := VBoxContainer.new()
	head_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_text)
	var title := _label(tr("TH_LEVEL") % [eco.townhall_level, eco.max_level()], 18, TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_override("font", Design.title_font())
	head_text.add_child(title)
	head_text.add_child(_caption(tr("TH_STATS") % [eco.housing(), eco.free_builders(), eco.builders(), eco.training_slots()]))
	_goals_list.add_child(head)

	var perk_names := PackedStringArray()
	for perk in eco.perks():
		perk_names.append(tr(str(perk.name_key)))
	if not perk_names.is_empty():
		_goals_list.add_child(_info_card(tr("TH_SKILLS"), " · ".join(perk_names), Design.TEAL_SOFT))

	if eco.townhall_upgrade_left >= 0.0:
		var card := _info_card(tr("TH_UPGRADING_TITLE") % (eco.townhall_level + 1), tr("TH_TIME_LEFT") % _format_days(eco.townhall_upgrade_days_left()), Design.SKY_SOFT)
		var bar := ProgressBar.new()
		var total := float(eco.level_def(eco.townhall_level + 1).get("days", 1.0))
		bar.max_value = 1.0
		bar.value = 1.0 - eco.townhall_upgrade_left / maxf(total, 0.01)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 12)
		card.get_child(0).add_child(bar)
		_goals_list.add_child(card)
		return
	if eco.townhall_level >= eco.max_level():
		_goals_list.add_child(_info_card(tr("TH_MAX"), tr("TH_MAX_TEXT"), Design.CREAM_DEEP))
		return

	var next: Dictionary = eco.level_def(eco.townhall_level + 1)
	var unlocks := PackedStringArray()
	var current: Dictionary = eco.level_def().get("buildings", {})
	for id in next.get("buildings", {}):
		if int(current.get(id, 0)) <= 0:
			unlocks.append(tr(str(eco.defs.get(id, {}).get("name_key", id))))
	for p in next.get("professions", []):
		if not (p in eco.level_def().get("professions", [])):
			unlocks.append(tr(str(eco.professions.get(p, {}).get("name_key", p))))
	for perk in next.get("perks", []):
		unlocks.append(tr(str(perk.name_key)))
	var lines := PackedStringArray()
	if not unlocks.is_empty():
		lines.append(tr("TH_UNLOCKS") % ", ".join(unlocks))
	lines.append(tr("TH_MORE") % [int(next.get("housing", 0)), int(next.get("builders", 1))])
	var need_pop := int(next.get("requires", {}).get("population", 0))
	lines.append(tr("TH_NEEDS_POP") % [need_pop, eco.population])
	lines.append(tr("TH_COST") % [_cost_text(next.get("cost", {})), _format_days(float(next.get("days", 1.0)))])
	_goals_list.add_child(_info_card(tr("TH_NEXT") % (eco.townhall_level + 1), "\n".join(lines), Design.CARD))
	var button := _icon_button("townhall", tr("TH_UPGRADE"), Vector2(0, 56))
	Design.make_primary(button, 18)
	var reason: String = eco.can_upgrade_townhall()
	button.disabled = reason != ""
	if reason != "":
		button.text = tr(reason)
	button.pressed.connect(func():
		if GameState.sim.economy.upgrade_townhall():
			Haptics.medium()
			_show_toast(tr("TH_STARTED"))
			_village_signature = ""
			_update_goals_sheet())
	_goals_list.add_child(button)


## Villagers: idle count, trainings in progress, one row per profession.
func _fill_people_tab() -> void:
	var eco = GameState.sim.economy
	_goals_list.add_child(_caption(tr("PEOPLE_SUMMARY") % [eco.idle_villagers(), eco.population, eco.training.size(), eco.training_slots()]))
	for t in eco.training:
		var pdef: Dictionary = eco.professions.get(t.profession, {})
		var days := float(pdef.get("days", 0.25))
		var card := _info_card(tr("TRAINING_ROW") % tr(str(pdef.get("name_key", t.profession))), "", Design.SKY_SOFT)
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.value = 1.0 - float(t.left) / maxf(days, 0.01)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		card.get_child(0).add_child(bar)
		_goals_list.add_child(card)
	var ids: Array = eco.professions.keys()
	for id in ids:
		var pdef: Dictionary = eco.professions[id]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", Design.panel(Design.CARD, 16, 8, eco.is_profession_unlocked(id)))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		row.add_child(line)
		line.add_child(_icon(str(pdef.get("icon", "people")), 32))
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(texts)
		var pname := _label(tr(str(pdef.get("name_key", id))), 15, TEXT)
		pname.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		texts.add_child(pname)
		if not eco.is_profession_unlocked(id):
			texts.add_child(_caption(tr("LOCKED_AT") % _profession_unlock_level(id)))
			row.modulate = Color(1, 1, 1, 0.55)
			_goals_list.add_child(row)
			continue
		texts.add_child(_caption(tr("PROF_STATUS") % [eco.trained_count(id), eco.profession_jobs(id)]))
		var minus := Button.new()
		minus.text = "-"
		minus.custom_minimum_size = Vector2(40, 44)
		minus.disabled = eco.trained_count(id) <= 0
		minus.pressed.connect(func():
			GameState.sim.economy.untrain(id)
			_village_signature = ""
			_update_goals_sheet())
		line.add_child(minus)
		var train := Button.new()
		var reason: String = eco.can_train(id)
		train.text = tr("TRAIN") % _cost_text(pdef.get("cost", {})) if reason == "" or reason == Economy.ERR_COST else tr(reason)
		train.custom_minimum_size = Vector2(118, 44)
		train.clip_text = true
		train.disabled = reason != ""
		if reason == "":
			Design.make_primary(train, 14)
		train.pressed.connect(func():
			if GameState.sim.economy.train(id):
				Haptics.light()
			_village_signature = ""
			_update_goals_sheet())
		line.add_child(train)
		_goals_list.add_child(row)


func _profession_unlock_level(profession: String) -> int:
	for def in GameState.sim.economy.townhall_levels:
		if profession in def.get("professions", []):
			return int(def.level)
	return 0


func _info_card(title: String, text: String, color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Design.panel(color, 16, 10, false))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var t := _label(title, 15, TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_override("font", Design.title_font())
	box.add_child(t)
	if text != "":
		var body := _label(text, 13, MUTED)
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(body)
	return card


## Game days shown as real time at normal speed (1 day = 60 s at x1).
func _format_days(days: float) -> String:
	var sim = GameState.sim
	var seconds := days * float(sim.ticks_per_day) / float(GameState.config.get("tick_rate_hz", 10))
	if seconds < 60.0:
		return tr("TIME_SECONDS") % maxi(1, ceili(seconds))
	return tr("TIME_MINUTES") % maxi(1, roundi(seconds / 60.0))


func _on_construction_done(cell: int) -> void:
	var id: String = GameState.sim.planet.buildings[cell]
	_show_toast(tr("CONSTRUCTION_DONE") % tr(str(GameState.sim.economy.defs.get(id, {}).get("name_key", id))))
	Haptics.light()
	GameState.sim.check_objectives()


func _on_training_done(profession: String) -> void:
	var name_key := str(GameState.sim.economy.professions.get(profession, {}).get("name_key", profession))
	_show_toast(tr("TRAINING_DONE") % tr(name_key))
	GameState.sim.check_objectives()


## Big celebration card when the town hall reaches a new level.
func _show_level_up(level: int) -> void:
	var eco = GameState.sim.economy
	_end_placement()
	_event_title.text = tr("LEVEL_UP_TITLE") % level
	var unlocks := PackedStringArray()
	var previous: Dictionary = eco.level_def(level - 1).get("buildings", {})
	for id in eco.level_def(level).get("buildings", {}):
		if int(previous.get(id, 0)) <= 0:
			unlocks.append(tr(str(eco.defs.get(id, {}).get("name_key", id))))
	for perk in eco.level_def(level).get("perks", []):
		unlocks.append(tr(str(perk.name_key)))
	_event_text.text = tr("LEVEL_UP_TEXT") % (", ".join(unlocks) if not unlocks.is_empty() else tr("LEVEL_UP_MORE"))
	for child in _event_choices.get_children():
		_event_choices.remove_child(child)
		child.queue_free()
	var ok := Button.new()
	ok.text = tr("LEVEL_UP_OK")
	ok.custom_minimum_size = Vector2(0, 54)
	Design.make_primary(ok, 18)
	ok.pressed.connect(func(): _close_sheets())
	_event_choices.add_child(ok)
	_show_sheet(_event_sheet)
	GameState.sim.check_objectives()
	Haptics.medium()


func _goal_row(obj: Dictionary, done: bool) -> PanelContainer:
	var sim = GameState.sim
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Design.panel(Design.TEAL_SOFT if done else Design.CARD, 16, 10, not done))
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := tr(str(obj.title_key))
	if title.contains("%d"):
		title = title % int(obj.value)
	elif title.contains("%s"):
		title = title % str(obj.value)
	var head := _label(("OK  " if done else "") + title, 15, GOOD if done else TEXT)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(head)
	if not done:
		var p := Objectives.progress(sim, obj)
		var bar := ProgressBar.new()
		bar.max_value = float(p[1])
		bar.value = float(p[0])
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		box.add_child(bar)
		box.add_child(_caption(tr("GOAL_STATUS") % [floori(float(p[0])), int(p[1]), _cost_text(obj.get("reward", {}))]))
	return panel


func _on_objective_completed(id: String) -> void:
	for obj in GameState.sim.objective_defs:
		if str(obj.id) == id:
			var title := tr(str(obj.title_key))
			if title.contains("%d"):
				title = title % int(obj.value)
			_show_toast(tr("GOAL_DONE") % [title, _cost_text(obj.get("reward", {}))])
			Haptics.medium()


# =============================================================================
# Events
# =============================================================================

func _build_event_sheet() -> PanelContainer:
	_event_title = _label("", 20, TEXT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Design.panel(Design.PARCHMENT, 26, 16))
	panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(_icon("event", 36))
	_event_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_event_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(_event_title)
	box.add_child(head)
	_event_text = _label("", 15, TEXT)
	_event_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_event_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_event_text)
	_event_choices = VBoxContainer.new()
	_event_choices.add_theme_constant_override("separation", 8)
	box.add_child(_event_choices)
	return panel


func _show_event(id: String) -> void:
	var ev := Events.find(GameState.sim.event_defs, id)
	if ev.is_empty():
		return
	_end_placement()
	_event_title.text = tr(str(ev.title_key))
	_event_text.text = tr(str(ev.text_key))
	for child in _event_choices.get_children():
		_event_choices.remove_child(child)
		child.queue_free()
	var choices: Array = ev.get("choices", [])
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var b := Button.new()
		b.text = "%s\n%s" % [tr(str(choice.label_key)), _effects_text(choice.get("effects", {}))]
		b.custom_minimum_size = Vector2(0, 58)
		b.pressed.connect(func():
			GameState.sim.resolve_event(i)
			Haptics.light()
			_close_sheets())
		_event_choices.add_child(b)
	_show_sheet(_event_sheet)
	close_requested.emit()
	Haptics.medium()


func _effects_text(effects: Dictionary) -> String:
	if effects.is_empty():
		return tr("EV_NOTHING")
	var parts := PackedStringArray()
	for key in effects:
		var value := float(effects[key])
		var label := ""
		match str(key):
			"population":
				label = tr("EFFECT_PEOPLE")
			"happiness":
				label = tr("HAPPINESS").to_lower()
			"health":
				label = tr("HEALTH").to_lower()
			_:
				label = tr(_res_key(str(key))).to_lower()
		parts.append("%s%d %s" % ["+" if value > 0.0 else "", int(value), label])
	return " · ".join(parts)


# =============================================================================
# Helpers
# =============================================================================

func _texture(icon_id: String) -> Texture2D:
	var path := ICON_DIR + icon_id + ".svg"
	return load(path) if ResourceLoader.exists(path) else null


func _icon(icon_id: String, size: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = _texture(icon_id)
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _icon_button(icon_name: String, text: String, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	if icon_name != "":
		button.icon = _texture(icon_name)
	button.custom_minimum_size = min_size
	button.clip_text = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if text == "" else HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", 30)
	button.add_theme_font_size_override("font_size", 18)
	return button


func _box(color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


func _res_key(res: String) -> String:
	var res_def: Dictionary = GameState.config.get("resources", {}).get(res, {})
	return str(res_def.get("name_key", "RES_" + res.to_upper()))


func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for res in cost:
		parts.append("%d %s" % [int(cost[res]), tr(_res_key(res)).to_lower()])
	return " + ".join(parts) if not parts.is_empty() else tr("FREE")


func _format_signed(value: float) -> String:
	var text := ("%.1f" % absf(value)).replace(".", tr("DECIMAL_SEPARATOR"))
	return ("+" if value >= 0.0 else "-") + text


## Converts the OS safe area (screen pixels) into viewport units and pads the UI.
func _apply_safe_area() -> void:
	var insets := [0.0, 0.0, 0.0, 0.0]  # left, top, right, bottom
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.window_get_size()
		var view := get_viewport().get_visible_rect().size
		if screen.x > 0 and screen.y > 0:
			var k := view / Vector2(screen)
			insets = [
				safe.position.x * k.x,
				safe.position.y * k.y,
				(screen.x - safe.end.x) * k.x,
				(screen.y - safe.end.y) * k.y,
			]
	_margin.add_theme_constant_override("margin_left", int(insets[0] + BASE_PADDING))
	_margin.add_theme_constant_override("margin_top", int(insets[1] + BASE_PADDING))
	_margin.add_theme_constant_override("margin_right", int(insets[2] + BASE_PADDING))
	_margin.add_theme_constant_override("margin_bottom", int(insets[3] + BASE_PADDING))


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The "Diorama doux" theme (see scripts/ui/design.gd).
func _make_theme() -> Theme:
	return Design.make_theme()
```


### FICHIER : scripts/ui/start_menu.gd

```gdscript
## Start screen: continue the current planet, create a new one with options
## (name, size, oceans, relief, colors, seed), or replay the tutorial.
extends Control

signal closed
signal tutorial_requested

const UiKit := preload("res://scripts/ui/ui_kit.gd")
const Haptics := preload("res://scripts/platform/haptics.gd")
const Design := preload("res://scripts/ui/design.gd")

var _main_page: VBoxContainer
var _new_page: VBoxContainer
var _options := {}
var _confirm := false
var _create_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var gradient := Gradient.new()
	gradient.set_color(0, Color(Design.CREAM, 0.0))
	gradient.set_color(1, Color(Design.CREAM, 0.97))
	gradient.add_point(0.45, Color(Design.CREAM, 0.35))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	_main_page = _build_main_page()
	stack.add_child(_main_page)
	_new_page = _build_new_page()
	stack.add_child(_new_page)
	open("main")


func open(page: String) -> void:
	visible = true
	_main_page.visible = page == "main"
	_new_page.visible = page == "new"
	if page == "new":
		_reset_options()
		_refill_new_page()


# --- Main page -------------------------------------------------------------------

func _build_main_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := UiKit.label(tr("APP_TITLE"), 40)
	title.add_theme_font_override("font", Design.title_font())
	title.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.8))
	title.add_theme_constant_override("shadow_offset_y", 2)
	page.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(spacer)  # The real planet shows through here.

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Design.panel(Design.CREAM, 30, 18))
	page.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var sim = GameState.sim
	var current := UiKit.label(tr("START_CURRENT") % [sim.custom.planet_name, sim.day(), sim.economy.population], 16, UiKit.MUTED)
	box.add_child(current)
	var play := UiKit.button(tr("START_CONTINUE"), "", 62)
	Design.make_primary(play, 22)
	play.add_theme_font_size_override("font_size", 22)
	play.pressed.connect(func():
		Haptics.light()
		visible = false
		closed.emit())
	box.add_child(play)
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var new_planet := UiKit.button(tr("START_NEW"), "build", 54)
	new_planet.pressed.connect(func(): open("new"))
	row.add_child(new_planet)
	var tuto := UiKit.button(tr("START_TUTORIAL"), "help", 54)
	tuto.pressed.connect(func():
		visible = false
		tutorial_requested.emit()
		closed.emit())
	row.add_child(tuto)
	return page


# --- New planet page -------------------------------------------------------------

func _build_new_page() -> VBoxContainer:
	var holder := VBoxContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", Design.panel(Design.CREAM, 30, 16))
	holder.add_child(card)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	card.add_child(page)
	var title := UiKit.label(tr("NEW_PLANET_TITLE"), 26)
	title.add_theme_font_override("font", Design.title_font())
	page.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	page.add_child(actions)
	var back := UiKit.button(tr("BACK"), "", 54)
	back.pressed.connect(func(): open("main"))
	actions.add_child(back)
	_create_button = UiKit.button(tr("NEW_PLANET"), "", 54)
	Design.make_primary(_create_button, 18)
	_create_button.pressed.connect(_on_create)
	actions.add_child(_create_button)
	return holder


func _reset_options() -> void:
	var options: Dictionary = GameState.config.get("customization", {})
	_confirm = false
	_options = {
		"name": GameState.sim.generate_name(randi(), GameState.sim.name_syllables),
		"frequency": int(options.get("default_size", 12)),
		"water": "balanced",
		"relief": "normal",
		"palette": "classic",
		"seed_text": "",
	}


func _refill_new_page() -> void:
	var content: VBoxContainer = _new_page.find_child("Content", true, false)
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	var options: Dictionary = GameState.config.get("customization", {})
	_create_button.text = tr("NEW_PLANET")

	content.add_child(_caption(tr("PLANET_NAME")))
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	var name_edit := LineEdit.new()
	name_edit.text = _options.name
	name_edit.max_length = 18
	name_edit.custom_minimum_size = Vector2(0, 46)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(text: String): _options["name"] = text)
	name_row.add_child(name_edit)
	var dice := Button.new()
	dice.icon = UiKit.texture("dice")
	dice.add_theme_constant_override("icon_max_width", 30)
	dice.custom_minimum_size = Vector2(46, 46)
	dice.pressed.connect(func():
		_options["name"] = GameState.sim.generate_name(randi(), GameState.sim.name_syllables)
		name_edit.text = _options.name
		Haptics.light())
	name_row.add_child(dice)
	content.add_child(name_row)

	content.add_child(_caption(tr("PLANET_SIZE")))
	var sizes := {}
	var order := 0
	for size in options.get("planet_sizes", []):
		var f := int(size.frequency)
		sizes[str(f)] = {"name_key": size.name_key, "order": order, "subtitle": tr("CELLS_N") % (10 * f * f + 2)}
		order += 1
	content.add_child(UiKit.choice_grid(sizes, str(_options.frequency), func(id: String): _options["frequency"] = int(id), 2))

	content.add_child(_caption(tr("PLANET_WATER")))
	content.add_child(UiKit.choice_grid(options.get("water_levels", {}), _options.water, func(id: String): _options["water"] = id))
	content.add_child(_caption(tr("PLANET_RELIEF")))
	content.add_child(UiKit.choice_grid(options.get("reliefs", {}), _options.relief, func(id: String): _options["relief"] = id))
	content.add_child(_caption(tr("PALETTE")))
	content.add_child(UiKit.choice_grid(options.get("palettes", {}), _options.palette, func(id: String): _options["palette"] = id))

	content.add_child(_caption(tr("PLANET_SEED")))
	var seed_edit := LineEdit.new()
	seed_edit.placeholder_text = tr("PLANET_SEED_HINT")
	seed_edit.custom_minimum_size = Vector2(0, 46)
	seed_edit.text_changed.connect(func(text: String): _options["seed_text"] = text)
	content.add_child(seed_edit)
	content.add_child(_caption(tr("NEW_PLANET_INFO")))


func _on_create() -> void:
	if not _confirm:
		_confirm = true
		_create_button.text = tr("NEW_PLANET_CONFIRM")
		Haptics.medium()
		return
	var options: Dictionary = GameState.config.get("customization", {})
	var water: Dictionary = options.get("water_levels", {}).get(_options.water, {})
	var relief: Dictionary = options.get("reliefs", {}).get(_options.relief, {})
	var world := {
		"frequency": _options.frequency,
		"name": _options.name,
		"palette": _options.palette,
		"seed": GameState.seed_from_text(str(_options.seed_text)),
	}
	if water.has("ocean_fraction"):
		world["ocean_fraction"] = water.ocean_fraction
	for key in ["hills_threshold", "mountain_threshold"]:
		if relief.has(key):
			world[key] = relief[key]
	GameState.start_menu_shown = true
	GameState.new_world(world)


func _caption(text: String) -> Label:
	return UiKit.label(text, 14, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
```


### FICHIER : scripts/ui/ui_kit.gd

```gdscript
## Small shared helpers to build the interface in code (labels, panels,
## icons, choice grids). Keeps every screen consistent.
extends RefCounted

const ICON_DIR := "res://assets/icons/ui/"
const Design := preload("res://scripts/ui/design.gd")
const TEXT := Design.INK
const MUTED := Design.INK_SOFT
const PANEL_BG := Design.CREAM


static func box(color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


static func label(text: String, size: int, color: Color = TEXT, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func texture(icon_id: String) -> Texture2D:
	var path := ICON_DIR + icon_id + ".svg"
	return load(path) if ResourceLoader.exists(path) else null


static func icon(icon_id: String, size: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture(icon_id)
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func button(text: String, icon_id: String = "", min_height: int = 50) -> Button:
	var b := Button.new()
	b.text = text
	if icon_id != "":
		b.icon = texture(icon_id)
		b.add_theme_constant_override("icon_max_width", 30)
	b.custom_minimum_size = Vector2(0, min_height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	return b


## One-choice toggle buttons on a grid. `choices`: id -> {name_key, order, subtitle?}.
static func choice_grid(choices: Dictionary, current: String, on_pick: Callable, columns: int = 3) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = mini(columns, maxi(choices.size(), 1))
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var ids: Array = choices.keys()
	ids.sort_custom(func(a, b): return int(choices[a].get("order", 0)) < int(choices[b].get("order", 0)))
	var group := ButtonGroup.new()
	for id in ids:
		var choice: Dictionary = choices[id]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.text = TranslationServer.translate(str(choice.get("name_key", id)))
		if choice.has("subtitle"):
			b.text += "\n" + str(choice.subtitle)
		b.button_pressed = str(id) == current
		b.pressed.connect(func(): on_pick.call(str(id)))
		grid.add_child(b)
	return grid


## Round color swatches; `on_pick` receives the hex string.
static func swatches(colors: Array, current: String, on_pick: Callable) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var group := ButtonGroup.new()
	for hex in colors:
		var swatch := Button.new()
		swatch.toggle_mode = true
		swatch.button_group = group
		swatch.custom_minimum_size = Vector2(36, 40)
		swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var color := Color(str(hex))
		swatch.add_theme_stylebox_override("normal", box(color, 22, 0))
		swatch.add_theme_stylebox_override("hover", box(color.lightened(0.1), 22, 0))
		var chosen := box(color, 22, 0)
		chosen.set_border_width_all(4)
		chosen.border_color = Color.WHITE
		swatch.add_theme_stylebox_override("pressed", chosen)
		swatch.add_theme_stylebox_override("hover_pressed", chosen)
		swatch.button_pressed = str(hex) == current
		swatch.pressed.connect(func(): on_pick.call(str(hex)))
		grid.add_child(swatch)
	return grid


## Converts a list of {id, name_key, ...} into a choice dictionary.
static func choices_from_list(items: Array, subtitle_fn: Callable = Callable()) -> Dictionary:
	var out := {}
	var order := 0
	for item in items:
		var entry := {"name_key": item.get("name_key", item.get("id", "")), "order": order}
		if subtitle_fn.is_valid():
			entry["subtitle"] = subtitle_fn.call(item)
		out[str(item.get("id", order))] = entry
		order += 1
	return out
```
