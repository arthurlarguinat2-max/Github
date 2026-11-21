## Development helper: takes screenshots of key screens, then quits.
## Only active when the game is started with:  -- --screenshot-dir=<folder>
## Used by CI (.github/workflows/screenshots.yml) to check the visual design.
extends Node

var hud
var out_dir := ""
var _frame := 0
const SHOTS := [
	[90, "1_accueil", "start"],
	[180, "2_jeu", "game"],
	[240, "3_construire", "build"],
	[300, "4_besoins", "needs"],
	[360, "5_reglages", "settings"],
	[420, "6_objectifs", "goals"],
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


func _capture(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var image := get_viewport().get_texture().get_image()
	image.save_png(out_dir.path_join(name + ".png"))
	print("screenshot: ", name)
