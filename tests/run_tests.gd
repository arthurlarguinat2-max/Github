## Headless test runner.
##   godot --headless --path . -s res://tests/run_tests.gd
## Runs every tests/unit/test_*.gd and exits with code 1 on any failure.
extends SceneTree

const UNIT_DIR := "res://tests/unit/"


func _initialize() -> void:
	var total := 0
	var failed := 0
	var files := DirAccess.get_files_at(UNIT_DIR)
	files.sort()
	for file_name in files:
		if not (file_name.begins_with("test_") and file_name.ends_with(".gd")):
			continue
		var script: GDScript = load(UNIT_DIR + file_name)
		if script == null or not script.can_instantiate():
			print("✗ %s: failed to load (parse error?)" % file_name)
			failed += 1
			continue
		for method in script.get_script_method_list():
			var name: String = method.name
			if not name.begins_with("test_"):
				continue
			total += 1
			var suite = script.new()  # Fresh instance per test: no shared state.
			suite._current = "%s::%s" % [file_name, name]
			suite.call(name)
			if suite.failures.is_empty():
				print("✓ %s" % suite._current)
			else:
				failed += 1
				for f in suite.failures:
					print("✗ %s" % f)
	print("\n%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 or total == 0 else 0)
