extends MarginContainer
## Keeps all HUD and touch UI inside the device safe area (notch, home bar).
## On desktop it only applies a small fixed margin.

const MIN_MARGIN := 16.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_apply)
	_apply()


func _apply() -> void:
	var left := MIN_MARGIN
	var top := MIN_MARGIN
	var right := MIN_MARGIN
	var bottom := MIN_MARGIN
	if OS.has_feature("mobile"):
		var window := Vector2(DisplayServer.window_get_size())
		var safe := Rect2(DisplayServer.get_display_safe_area())
		var view := get_viewport_rect().size
		if window.x > 0.0 and window.y > 0.0:
			var scale_x := view.x / window.x
			var scale_y := view.y / window.y
			left = maxf(left, safe.position.x * scale_x)
			top = maxf(top, safe.position.y * scale_y)
			right = maxf(right, (window.x - safe.end.x) * scale_x)
			bottom = maxf(bottom, (window.y - safe.end.y) * scale_y)
	add_theme_constant_override("margin_left", int(left))
	add_theme_constant_override("margin_top", int(top))
	add_theme_constant_override("margin_right", int(right))
	add_theme_constant_override("margin_bottom", int(bottom))
