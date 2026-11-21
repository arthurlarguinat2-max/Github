## Main scene: assembles the 3D world (planet, sun, camera, environment) and the HUD.
## Built in code to keep the .tscn minimal and merge-friendly.
extends Node3D

const PlanetView := preload("res://scripts/render/planet_view.gd")
const Hud := preload("res://scripts/ui/hud.gd")

var planet: PlanetView
var sun_pivot: Node3D
var sun: DirectionalLight3D
var hud: Hud


func _ready() -> void:
	_build_environment()
	var cam := _build_camera()
	_build_sun()
	hud = Hud.new()
	add_child(hud)

	var sim = GameState.sim
	planet = PlanetView.new()
	add_child(planet)
	planet.setup(sim.planet, sim.terrain_defs, cam, sim.world_seed)
	planet.focus_cell(sim.economy.village_center)
	sim.economy.changed.connect(planet.refresh_buildings)
	planet.ui_blocks_point = hud.blocks_point
	planet.cell_selected.connect(hud.show_cell)
	planet.selection_cleared.connect(hud.hide_cell)
	hud.close_requested.connect(planet.clear_selection)


func _process(_delta: float) -> void:
	# Day/night: the sun orbits the planet following the simulated time of day,
	# smoothed by the stepper's interpolation alpha.
	var sim = GameState.sim
	var t: float = sim.time_of_day() + GameState.stepper.interpolation_alpha() / float(sim.ticks_per_day)
	sun_pivot.rotation.y = t * TAU


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.1)
	# Soft blue ambient so the night side stays readable.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.42, 0.65)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _build_camera() -> Camera3D:
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH  # Portrait: fit the planet to the width.
	cam.fov = 42.0
	cam.near = 0.02
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
