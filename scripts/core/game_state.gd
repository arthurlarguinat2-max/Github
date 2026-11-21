## Autoload "GameState": owns the Simulation, drives it with fixed ticks,
## handles autosave and offline progress. The bridge between the pure
## simulation and the rest of the app (rendering, UI, OS events).
extends Node

const Simulation := preload("res://scripts/simulation/simulation.gd")
const FixedStepper := preload("res://scripts/simulation/fixed_stepper.gd")
const SaveManager := preload("res://scripts/core/save_manager.gd")
const Config := preload("res://scripts/core/config.gd")

signal ticked

var config: Dictionary
var sim: Simulation
var stepper: FixedStepper
## The start screen is shown once per app launch (not after a scene reload).
var start_menu_shown := false
## Days simulated while the app was closed; the UI shows then clears it.
var pending_offline_days := 0
var _autosave_timer := 0.0
## False when the save on disk comes from a newer app version (never overwrite it).
var _saving_enabled := true


func _ready() -> void:
	# Keep simulating when a modal UI pauses the tree later on.
	process_mode = Node.PROCESS_MODE_ALWAYS
	config = Config.game_config()
	config["terrains"] = Config.load_json("res://data/terrains.json").get("terrains", {})
	config["resources"] = Config.load_json("res://data/resources.json").get("resources", {})
	var buildings_file := Config.load_json("res://data/buildings.json")
	config["buildings"] = buildings_file.get("buildings", {})
	config["start"] = buildings_file.get("start", {})
	config["building_categories"] = buildings_file.get("categories", [])
	config["customization"] = Config.load_json("res://data/customization.json")
	config["objectives"] = Config.load_json("res://data/objectives.json").get("objectives", [])
	config["events"] = Config.load_json("res://data/events.json").get("events", [])
	config["tutorial"] = Config.load_json("res://data/tutorial.json")
	stepper = FixedStepper.new(float(config.get("tick_rate_hz", 10)), int(config.get("max_ticks_per_frame", 40)))
	_load_or_create()


func _process(delta: float) -> void:
	var ticks := stepper.advance(delta, sim.speed)
	if ticks > 0:
		sim.run_ticks(ticks)
		ticked.emit()
	_autosave_timer += delta
	if _autosave_timer >= float(config.get("autosave_interval_seconds", 30)):
		save_game()


func _notification(what: int) -> void:
	# iOS can kill a backgrounded app at any time: save as soon as we leave.
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			save_game()
		NOTIFICATION_APPLICATION_RESUMED:
			stepper.reset()


func save_game() -> void:
	_autosave_timer = 0.0
	if not _saving_enabled:
		return
	var err := SaveManager.save_to_file(sim.to_dict())
	if err != OK:
		push_warning("Save failed: %s" % error_string(err))


## Replaces the current planet with a brand new one, saves it and restarts
## the scene. The previous planet is lost.
## options: frequency, ocean_fraction, hills_threshold, mountain_threshold,
##          seed (-1 = random), name ("" = generated), palette, village_color.
func new_world(options: Dictionary) -> void:
	var world_config := config.duplicate(true)
	for key in ["frequency", "ocean_fraction", "hills_threshold", "mountain_threshold"]:
		if options.has(key):
			world_config["planet"][key] = options[key]
	var world_seed := int(options.get("seed", -1))
	if world_seed < 0:
		world_seed = randi()
	sim = Simulation.new(world_seed, world_config)
	if str(options.get("name", "")).strip_edges() != "":
		sim.custom["planet_name"] = str(options.name).strip_edges()
	for key in ["palette", "village_color", "rings", "moon"]:
		if options.has(key):
			sim.custom[key] = options[key]
	_saving_enabled = true
	stepper.reset()
	save_game()
	get_tree().reload_current_scene()


## Turns any text into a planet seed, so friends can share planets.
static func seed_from_text(text: String) -> int:
	var clean := text.strip_edges()
	if clean == "":
		return -1
	if clean.is_valid_int():
		return absi(clean.to_int())
	return absi(hash(clean.to_lower()))


func new_game(seed_value: int = -1) -> void:
	if seed_value < 0:
		seed_value = randi()
	sim = Simulation.new(seed_value, config)


func _load_or_create() -> void:
	var result := SaveManager.load_from_file()
	match result.status:
		SaveManager.LoadStatus.OK:
			var envelope: Dictionary = result.envelope
			new_game(int(envelope.game.get("world_seed", 0)))
			sim.from_dict(envelope.game)
			_apply_offline_progress(float(envelope.get("saved_at_unix", 0.0)))
		SaveManager.LoadStatus.TOO_NEW:
			# Never overwrite a save from a newer version: play on a temporary world.
			push_warning("Save is from a newer version; starting a temporary world.")
			_saving_enabled = false
			new_game()
		_:
			new_game()


func _apply_offline_progress(saved_at_unix: float) -> void:
	if saved_at_unix <= 0.0:
		return
	var away := Time.get_unix_time_from_system() - saved_at_unix
	if away < 60.0:
		return
	var day_before := sim.day()
	sim.advance_offline(
		away,
		float(config.get("tick_rate_hz", 10)),
		float(config.get("offline_progress_cap_hours", 8)) * 3600.0,
		float(config.get("offline_progress_efficiency", 0.5)))
	pending_offline_days = sim.day() - day_before
