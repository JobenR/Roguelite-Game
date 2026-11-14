class_name ShapeVisual
extends Node2D
## Placeholder visual drawn in code. Two styles:
##
##   Brush ink (when the data has "core"): a black shape with a ragged brushed
##   edge and a soft wet halo, plus a glowing coloured core. Used for the horde;
##   the core colour is how enemy types are told apart.
##
##   Plain (otherwise): a filled polygon with outline, highlight, and optional
##   glow halo, motion streak, or seal. Used for the player, shots and gems.
##
## Visual contract (any replacement, e.g. a sprite scene, must provide these):
##   setup(data: Dictionary, radius: float) -> void
##   flash() -> void
## Gameplay code only ever calls those two methods.
##
## Data keys: color, outline, outline_width, sides (0 = circle), rotation_deg,
## brush_shot (bool: draw as a flicked brush stroke; needs streak),
## core (glowing core colour), core_shape ("square" for the player's seal), ring (bool: a ring round the core, for bosses),
## aura (colour of a haze behind the shape), halo (glow colour behind a plain
## shape), seal (colour of a square mark), streak (motion trail length),
## glow (streak colour), shadow (bool).

const FLASH_TIME := 0.08
const FLASH_COLOR := Color(3.0, 3.0, 3.0)

var _points: PackedVector2Array = PackedVector2Array()
var _outline_points: PackedVector2Array = PackedVector2Array()
var _highlight: PackedVector2Array = PackedVector2Array()
var _wet: PackedVector2Array = PackedVector2Array()
var _color: Color = Color.WHITE
var _outline: Color = Color.BLACK
var _outline_width: float = 0.2
var _radius: float = 10.0
var _brush: bool = false
var _core: Color = Color.WHITE
var _ring: bool = false
var _core_square: bool = false
var _brush_shot: bool = false
var _blot: PackedVector2Array = PackedVector2Array()
var _aura: Color = Color(0, 0, 0, 0)
var _halo: Color = Color(0, 0, 0, 0)
var _seal: Color = Color(0, 0, 0, 0)
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
	_outline_width = float(data.get("outline_width", 0.2))
	_brush = data.has("core")
	_core = Color(String(data.get("core", "#ffffff")))
	_ring = bool(data.get("ring", false))
	_core_square = String(data.get("core_shape", "")) == "square"
	_brush_shot = bool(data.get("brush_shot", false))
	_aura = Color(String(data["aura"])) if data.has("aura") else Color(0, 0, 0, 0)
	_halo = Color(String(data["halo"])) if data.has("halo") else Color(0, 0, 0, 0)
	_seal = Color(String(data["seal"])) if data.has("seal") else Color(0, 0, 0, 0)
	_streak = float(data.get("streak", 0.0))
	_shadow = bool(data.get("shadow", true))
	_glow = Color(String(data.get("glow", _color.lightened(0.4).to_html())))
	var sides := int(data.get("sides", 0))
	if sides < 3:
		sides = 20  # circle
	var offset := deg_to_rad(float(data.get("rotation_deg", 0.0)))
	if _brush:
		_build_brush_shape(sides, offset)
	else:
		_points.resize(sides)
		_highlight.resize(sides)
		for i in sides:
			var p := Vector2.from_angle(offset + TAU * i / sides) * radius
			_points[i] = p
			_highlight[i] = p * 0.5 + Vector2(-radius, -radius) * 0.22
		_outline_points = _points.duplicate()
		_outline_points.append(_points[0])
	_flash_left = 0.0
	modulate = Color.WHITE
	queue_redraw()


## A polygon whose edge is nudged in and out along its own radius, so it looks
## brushed. Moving points only along the radius keeps the outline from
## crossing itself.
func _build_brush_shape(sides: int, offset: float) -> void:
	var per_edge := 5 if sides < 12 else 1
	var count := sides * per_edge
	_points.resize(count)
	_wet.resize(count)
	for s in sides:
		var a := Vector2.from_angle(offset + TAU * s / sides) * _radius * 1.12
		var b := Vector2.from_angle(offset + TAU * (s + 1) / sides) * _radius * 1.12
		for k in per_edge:
			var p := a.lerp(b, float(k) / per_edge)
			# Corners stay sharp; the middles of edges fray more.
			var fray := 0.05 if k == 0 else 0.11
			_points[s * per_edge + k] = p * randf_range(1.0 - fray, 1.0 + fray)
			_wet[s * per_edge + k] = p * randf_range(1.18, 1.4)
	# The pooled shadow under the shape: a lopsided blot, drawn offset.
	_blot.resize(14)
	for i in 14:
		_blot[i] = Vector2.from_angle(TAU * i / 14.0) * _radius * randf_range(1.15, 1.6)


func flash() -> void:
	_flash_left = FLASH_TIME
	if _brush:
		# Black ink cannot be brightened by tinting, so redraw it lit up.
		queue_redraw()
	else:
		modulate = FLASH_COLOR
	set_process(true)


func _process(delta: float) -> void:
	_flash_left -= delta
	if _flash_left <= 0.0:
		modulate = Color.WHITE
		set_process(false)
		if _brush:
			queue_redraw()


func _draw() -> void:
	if _points.size() < 3:
		return
	if _brush:
		_draw_brush()
	else:
		_draw_plain()


func _draw_brush() -> void:
	var body := _core.lerp(Color.WHITE, 0.6) if _flash_left > 0.0 else _color
	if _streak > 0.0:
		# A dry brush drag behind fast enemies.
		var tail := PackedVector2Array([Vector2(0.0, -_radius * 0.8), Vector2(-_streak * 3.2, 0.0), Vector2(0.0, _radius * 0.8)])
		draw_polygon(tail, PackedColorArray([Color(_color, 0.5), Color(_color, 0.0), Color(_color, 0.5)]))
	if _aura.a > 0.0:
		draw_circle(Vector2.ZERO, _radius * 2.2, Color(_aura, 0.2))
		draw_circle(Vector2.ZERO, _radius * 1.6, Color(_aura, 0.24))
	# The shade pooled under the shape, then the wet halo where the ink bled
	# into the paper, then a thin paper-coloured rim (so the body still shows
	# against black ink), then the body.
	draw_set_transform(Vector2(_radius * 0.22, _radius * 0.3))
	draw_colored_polygon(_blot, Color(_color, 0.2))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(_wet, Color(_color, 0.22))
	var rim := _points.duplicate()
	rim.append(_points[0])
	draw_polyline(rim, Color(0.94, 0.9, 0.82, 0.85), 3.0, true)
	draw_colored_polygon(_points, body)
	# The glowing core: stacked translucent discs stand in for a glow.
	var c := Vector2(0.0, -_radius * 0.06)
	var core_radius := _radius * 0.24
	for i in 4:
		draw_circle(c, core_radius * (3.0 - i * 0.55), Color(_core, 0.10 + 0.07 * i))
	if _core_square:
		# The player's seal: a glowing square.
		var half := core_radius * 1.15
		draw_rect(Rect2(c.x - half, c.y - half, half * 2.0, half * 2.0), _core)
		draw_rect(Rect2(c.x - half * 0.4, c.y - half * 0.4, half * 0.8, half * 0.8), Color.WHITE)
	else:
		draw_circle(c, core_radius, _core)
		draw_circle(c, core_radius * 0.42, Color.WHITE)
	if _ring:
		draw_arc(c, _radius * 0.62, 0.0, TAU, 40, Color(_core, 0.9), maxf(3.0, _radius * 0.07))
		draw_arc(c, _radius * 0.62, 0.0, TAU, 40, Color(_core, 0.25), maxf(8.0, _radius * 0.2))


func _draw_plain() -> void:
	if _brush_shot:
		# A flick of the brush: a wedge of ink tapering to nothing behind a
		# round head, with a soft glow, a faint dry drag and a speck of shine.
		for i in 3:
			draw_circle(Vector2.ZERO, _radius * (2.6 - i * 0.5), Color(_glow, 0.10 + 0.06 * i))
		draw_polygon(PackedVector2Array([Vector2(0.0, -_radius * 1.6), Vector2(-_streak * 3.4, 0.0), Vector2(0.0, _radius * 1.6)]),
				PackedColorArray([Color(_glow, 0.3), Color(_glow, 0.0), Color(_glow, 0.3)]))
		draw_colored_polygon(PackedVector2Array([Vector2(0.0, -_radius), Vector2(-_streak * 2.4, 0.0), Vector2(0.0, _radius)]), _color)
		draw_circle(Vector2.ZERO, _radius * 1.1, _color)
		draw_circle(Vector2(_radius * 0.3, -_radius * 0.25), _radius * 0.3, Color(0.96, 0.93, 0.85, 0.95))
		return
	if _streak > 0.0:
		# A tapered comet tail fading to nothing, with a soft glow at the head.
		var wide := PackedVector2Array([Vector2(0.0, -_radius * 1.5), Vector2(-_streak * 2.6, 0.0), Vector2(0.0, _radius * 1.5)])
		draw_polygon(wide, PackedColorArray([Color(_glow, 0.45), Color(_glow, 0.0), Color(_glow, 0.45)]))
		var core := PackedVector2Array([Vector2(0.0, -_radius * 0.8), Vector2(-_streak * 1.5, 0.0), Vector2(0.0, _radius * 0.8)])
		draw_polygon(core, PackedColorArray([Color(_color, 0.9), Color(_color, 0.0), Color(_color, 0.9)]))
		draw_circle(Vector2.ZERO, _radius * 2.1, Color(_glow, 0.22))
	if _halo.a > 0.0:
		for i in 4:
			draw_circle(Vector2.ZERO, _radius * (2.4 - i * 0.35), Color(_halo, 0.08 + 0.05 * i))
	if _shadow:
		draw_set_transform(Vector2(_radius * 0.18, _radius * 0.32))
		draw_colored_polygon(_points, Color(0.0, 0.0, 0.0, 0.28))
		draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(_points, _color)
	draw_colored_polygon(_highlight, _color.lightened(0.35))
	draw_polyline(_outline_points, _outline, maxf(2.0, _radius * _outline_width), true)
	if _streak > 0.0:
		draw_circle(Vector2(_radius * 0.25, 0.0), _radius * 0.35, Color(1, 1, 1, 0.9))
	if _seal.a > 0.0:
		var half := _radius * 0.36
		draw_rect(Rect2(-half, -half, half * 2.0, half * 2.0), _seal)
