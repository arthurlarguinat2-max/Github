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
