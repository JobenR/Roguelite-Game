class_name ShapeVisual
extends Node2D
## Placeholder visual: a flat polygon drawn in code.
##
## Visual contract (any replacement, e.g. a sprite scene, must provide these):
##   setup(data: Dictionary, radius: float) -> void
##   flash() -> void
## Gameplay code only ever calls those two methods.

const FLASH_TIME := 0.08
const FLASH_COLOR := Color(3.0, 3.0, 3.0)

var _points: PackedVector2Array = PackedVector2Array()
var _color: Color = Color.WHITE
var _flash_left: float = 0.0


func _ready() -> void:
	set_process(false)


func setup(data: Dictionary, radius: float) -> void:
	_color = Color(String(data.get("color", "#ffffff")))
	var sides := int(data.get("sides", 0))
	if sides < 3:
		sides = 20  # circle
	var offset := deg_to_rad(float(data.get("rotation_deg", 0.0)))
	_points.resize(sides)
	for i in sides:
		_points[i] = Vector2.from_angle(offset + TAU * i / sides) * radius
	modulate = Color.WHITE
	queue_redraw()


func flash() -> void:
	_flash_left = FLASH_TIME
	modulate = FLASH_COLOR
	set_process(true)


func _process(delta: float) -> void:
	_flash_left -= delta
	if _flash_left <= 0.0:
		modulate = Color.WHITE
		set_process(false)


func _draw() -> void:
	if _points.size() >= 3:
		draw_colored_polygon(_points, _color)
