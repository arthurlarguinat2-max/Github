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


func _ready() -> void:
	_build_environment()
	_build_stars()
	var cam := _build_camera()
	_build_sun()
	hud = Hud.new()
	add_child(hud)

	var sim = GameState.sim
	planet = PlanetView.new()
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


func _process(_delta: float) -> void:
	# Day/night: the sun orbits the planet following the simulated time of day,
	# smoothed by the stepper's interpolation alpha.
	var sim = GameState.sim
	var t: float = sim.time_of_day() + GameState.stepper.interpolation_alpha() / float(sim.ticks_per_day)
	sun_pivot.rotation.y = t * TAU


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
	var sky: Dictionary = skies.get(str(UserSettings.get_value("sky")), {})
	_env.background_color = Color(str(sky.get("color", "080a14")))
	var star_strength := float(sky.get("stars", 1.0))
	_stars.visible = star_strength > 0.0
	_star_material.albedo_color = Color(1, 1, 1, star_strength)


func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.03, 0.04, 0.08)
	# Soft blue ambient so the night side stays readable.
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.35, 0.42, 0.65)
	_env.ambient_light_energy = 0.45
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)


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
	sun.light_color = Color(1.0, 0.93, 0.8)  # Warm light.
	sun.light_energy = 1.3
	sun.shadow_enabled = false  # Shadows are costly on mobile.
	sun_pivot.add_child(sun)
	# Tilted sun so the terminator line crosses the planet nicely.
	sun.rotation = Vector3(deg_to_rad(-20), deg_to_rad(-60), 0)
