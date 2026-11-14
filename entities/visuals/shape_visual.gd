class_name ShapeVisual
extends Node2D
## Placeholder visual: a polygon drawn in code with a drop shadow, dark
## outline, highlight, and optional eyes or motion streak.
##
## Visual contract (any replacement, e.g. a sprite scene, must provide these):
##   setup(data: Dictionary, radius: float) -> void
##   flash() -> void
## Gameplay code only ever calls those two methods.
##
## Data keys: color, outline, sides (0 = circle), rotation_deg, eyes (bool),
## streak (length of a motion trail behind the shape), shadow (bool).

const FLASH_TIME := 0.08
const FLASH_COLOR := Color(3.0, 3.0, 3.0)

var _points: PackedVector2Array = PackedVector2Array()
var _outline_points: PackedVector2Array = PackedVector2Array()
var _highlight: PackedVector2Array = PackedVector2Array()
var _color: Color = Color.WHITE
var _outline: Color = Color.BLACK
var _radius: float = 10.0
var _eyes: bool = false
var _streak: float = 0.0
var _shadow: bool = true
var _glow: Color = Color.WHITE
var _flash_left: float = 0.0


func _ready() -> void:
	set_process(false)


func setup(data: Dictionary, radius: float) -> void:
	_radius = radius
	_color = Color(String(data.get("color", "#ffffff")))
	_outline = Color(String(data.get("outline", _color.darkened(0.6).to_html())))
	_eyes = bool(data.get("eyes", false))
	_streak = float(data.get("streak", 0.0))
	_shadow = bool(data.get("shadow", true))
	_glow = Color(String(data.get("glow", _color.lightened(0.4).to_html())))
	var sides := int(data.get("sides", 0))
	if sides < 3:
		sides = 20  # circle
	var offset := deg_to_rad(float(data.get("rotation_deg", 0.0)))
	_points.resize(sides)
	_highlight.resize(sides)
	for i in sides:
		var p := Vector2.from_angle(offset + TAU * i / sides) * radius
		_points[i] = p
		_highlight[i] = p * 0.5 + Vector2(-radius, -radius) * 0.22
	_outline_points = _points.duplicate()
	_outline_points.append(_points[0])
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
	if _points.size() < 3:
		return
	if _streak > 0.0:
		# A tapered comet tail fading to nothing, with a soft glow at the head.
		var wide := PackedVector2Array([Vector2(0.0, -_radius * 1.5), Vector2(-_streak * 2.6, 0.0), Vector2(0.0, _radius * 1.5)])
		draw_polygon(wide, PackedColorArray([Color(_glow, 0.45), Color(_glow, 0.0), Color(_glow, 0.45)]))
		var core := PackedVector2Array([Vector2(0.0, -_radius * 0.8), Vector2(-_streak * 1.5, 0.0), Vector2(0.0, _radius * 0.8)])
		draw_polygon(core, PackedColorArray([Color(_color, 0.9), Color(_color, 0.0), Color(_color, 0.9)]))
		draw_circle(Vector2.ZERO, _radius * 2.1, Color(_glow, 0.22))
	if _shadow:
		draw_set_transform(Vector2(_radius * 0.18, _radius * 0.32))
		draw_colored_polygon(_points, Color(0.0, 0.0, 0.0, 0.28))
		draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(_points, _color)
	draw_colored_polygon(_highlight, _color.lightened(0.35))
	draw_polyline(_outline_points, _outline, maxf(2.0, _radius * 0.2), true)
	if _streak > 0.0:
		draw_circle(Vector2(_radius * 0.25, 0.0), _radius * 0.35, Color(1, 1, 1, 0.9))
	if _eyes:
		var eye := _radius * 0.22
		for side: float in [-1.0, 1.0]:
			var c := Vector2(side * _radius * 0.3, -_radius * 0.08)
			draw_circle(c, eye, Color.WHITE)
			draw_circle(c + Vector2(0.0, eye * 0.25), eye * 0.55, Color(0.05, 0.05, 0.05))
