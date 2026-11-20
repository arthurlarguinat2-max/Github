## Minimal assertion base class for headless tests (no third-party addon).
## Each test file extends this; every method starting with "test_" is run.
extends RefCounted

var failures: PackedStringArray = []
var _current := ""


func _fail(message: String) -> void:
	failures.append("%s: %s" % [_current, message])


func assert_true(value: bool, message: String = "expected true") -> void:
	if not value:
		_fail(message)


func assert_false(value: bool, message: String = "expected false") -> void:
	if value:
		_fail(message)


func assert_eq(actual, expected, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		_fail("expected <%s> got <%s> %s" % [str(expected), str(actual), message])


func assert_almost_eq(actual: float, expected: float, tolerance: float = 1e-5, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		_fail("expected %f ± %f got %f %s" % [expected, tolerance, actual, message])
