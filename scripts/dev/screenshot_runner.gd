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
			planet.focus_cell(GameState.sim.economy.village_center)
			planet._zoom = planet._zoom_min + 0.15
			planet._zoom_target = planet._zoom
			planet._update_camera()
			_build_demo_village()
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
			if eco.can_build(i, id) == "" or eco.can_build(i, id) == eco.ERR_BUILDERS:
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
