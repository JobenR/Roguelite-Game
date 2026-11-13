class_name UpgradeIcon
extends Control
## Draws an upgrade's picture in code, so a card can be recognised without
## reading it. Icons are drawn in a 100x100 space centred on zero. To use art
## instead, replace this control with a TextureRect keyed by the same icon id.

const INK := Color("#1d4ed8")
const DARK := Color("#0b1b4d")
const LIGHT := Color("#93b4ff")
const WHITE := Color(1, 1, 1)
const ENEMY := Color("#3fbf4f")
const GOLD := Color("#fbbf24")

var icon_id: String = ""
var tint: Color = INK


func _draw() -> void:
	var s := minf(size.x, size.y) / 100.0
	draw_set_transform(size * 0.5, 0.0, Vector2(s, s))
	draw_circle(Vector2.ZERO, 48.0, Color(tint, 0.16))
	draw_arc(Vector2.ZERO, 48.0, 0.0, TAU, 48, Color(tint, 0.7), 2.5)
	match icon_id:
		"rapid_fire":
			for i in 3:
				_bullet(Vector2(-14.0 + i * 20.0, 18.0 - i * 18.0), 20.0)
				draw_line(Vector2(-40.0 + i * 20.0, 18.0 - i * 18.0), Vector2(-48.0 + i * 20.0, 18.0 - i * 18.0), LIGHT, 3.0)
		"damage":
			_drop(Vector2(0, 4), 26.0, INK)
			draw_line(Vector2(-11, 8), Vector2(11, 8), WHITE, 6.0)
			draw_line(Vector2(0, -3), Vector2(0, 19), WHITE, 6.0)
		"move_speed":
			for i in 3:
				var x := -24.0 + i * 20.0
				draw_polyline(PackedVector2Array([Vector2(x, -20), Vector2(x + 16, 0), Vector2(x, 20)]), Color(INK, 0.45 + i * 0.27), 8.0, true)
		"max_hp":
			var red := Color("#dc2626")
			draw_circle(Vector2(-12, -8), 15.0, red)
			draw_circle(Vector2(12, -8), 15.0, red)
			draw_colored_polygon(PackedVector2Array([Vector2(-26, -1), Vector2(26, -1), Vector2(0, 30)]), red)
			draw_circle(Vector2(-15, -12), 5.0, Color(1, 1, 1, 0.6))
		"pickup_radius":
			draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 40, Color(INK, 0.5), 3.0)
			draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, Color(INK, 0.8), 3.0)
			_gem(Vector2.ZERO, 11.0)
			_gem(Vector2(30, -22), 6.0)
			_gem(Vector2(-28, 20), 6.0)
		"pierce":
			_enemy(Vector2(-4, 0), 15.0)
			_enemy(Vector2(24, 0), 11.0)
			draw_line(Vector2(-42, 0), Vector2(36, 0), DARK, 6.0)
			draw_colored_polygon(PackedVector2Array([Vector2(44, 0), Vector2(30, -9), Vector2(30, 9)]), DARK)
		"multishot":
			_bullet(Vector2(16, -12), 34.0)
			_bullet(Vector2(16, 12), 34.0)
		"scatter":
			for i in 5:
				var dir := Vector2.from_angle(deg_to_rad(-44.0 + i * 22.0))
				draw_line(Vector2(-34, 0), Vector2(-34, 0) + dir * 62.0, Color(INK, 0.55), 4.0)
				draw_circle(Vector2(-34, 0) + dir * 66.0, 6.0, DARK)
			draw_circle(Vector2(-34, 0), 8.0, INK)
		"ricochet":
			var path := PackedVector2Array([Vector2(-40, 24), Vector2(-12, -18), Vector2(14, 16), Vector2(38, -22)])
			draw_polyline(path, DARK, 5.0, true)
			for i in range(1, 4):
				_enemy(path[i], 9.0)
			draw_circle(path[0], 6.0, INK)
		"explosive":
			var star := PackedVector2Array()
			for i in 16:
				star.append(Vector2.from_angle(TAU * i / 16.0) * (36.0 if i % 2 == 0 else 18.0))
			draw_colored_polygon(star, Color("#f97316"))
			draw_circle(Vector2.ZERO, 13.0, GOLD)
			draw_circle(Vector2.ZERO, 6.0, WHITE)
		"laser":
			draw_line(Vector2(-30, 22), Vector2(40, -30), Color(INK, 0.35), 18.0)
			draw_line(Vector2(-30, 22), Vector2(40, -30), INK, 9.0)
			draw_line(Vector2(-30, 22), Vector2(40, -30), WHITE, 3.0)
			draw_circle(Vector2(-30, 22), 11.0, DARK)
		"orbit":
			draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 40, Color(INK, 0.4), 3.0)
			draw_circle(Vector2.ZERO, 11.0, INK)
			for i in 3:
				var p := Vector2.from_angle(TAU * i / 3.0 - 0.5) * 30.0
				draw_circle(p, 9.0, DARK)
				draw_circle(p - Vector2(3, 3), 3.0, LIGHT)
		"healing_ink":
			_blot(INK)
			draw_line(Vector2(-13, 2), Vector2(13, 2), WHITE, 8.0)
			draw_line(Vector2(0, -11), Vector2(0, 15), WHITE, 8.0)
		"caustic_ink":
			_blot(Color("#4d7c0f"))
			for b: Vector3 in [Vector3(-10, 6, 7), Vector3(9, -4, 9), Vector3(4, 14, 4), Vector3(-6, -12, 4)]:
				draw_arc(Vector2(b.x, b.y), b.z, 0.0, TAU, 16, Color("#d9f99d"), 2.5)
		"broad_stroke":
			var wave := PackedVector2Array()
			for i in 13:
				wave.append(Vector2(-38.0 + i * 6.3, sin(i * 0.9) * 12.0))
			draw_polyline(wave, INK, 18.0, true)
			draw_polyline(wave, LIGHT, 3.0, true)
		"wide_ripple":
			draw_circle(Vector2.ZERO, 8.0, INK)
			for i in 3:
				draw_arc(Vector2.ZERO, 16.0 + i * 11.0, 0.0, TAU, 40, Color(INK, 0.9 - i * 0.25), 5.0 - i)
		"heavy_blots":
			_blot(INK)
			for i in 6:
				draw_circle(Vector2.from_angle(TAU * i / 6.0 + 0.4) * 36.0, 4.0 + (i % 3) * 2.0, INK)
		"slick_page":
			draw_line(Vector2(-38, 16), Vector2(38, 16), INK, 14.0)
			draw_circle(Vector2(-38, 16), 7.0, INK)
			draw_circle(Vector2(38, 16), 7.0, INK)
			for i in 3:
				var x := -22.0 + i * 18.0
				draw_polyline(PackedVector2Array([Vector2(x, -22), Vector2(x + 12, -10), Vector2(x, 2)]), DARK, 5.0, true)
		"steady_hand":
			var red := Color("#e11d48")
			draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 32, red, 5.0)
			draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 20, red, 4.0)
			for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				draw_line(dir * 18.0, dir * 38.0, red, 5.0)
		_:
			_drop(Vector2.ZERO, 24.0, INK)


func _bullet(tip: Vector2, length: float) -> void:
	draw_line(tip - Vector2(length, 0), tip, INK, 9.0)
	draw_circle(tip, 6.5, DARK)


func _drop(center: Vector2, r: float, color: Color) -> void:
	draw_circle(center, r, color)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-r * 0.86, -r * 0.5), center + Vector2(r * 0.86, -r * 0.5), center + Vector2(0, -r * 1.9)]), color)
	draw_circle(center + Vector2(-r * 0.35, -r * 0.2), r * 0.22, Color(1, 1, 1, 0.55))


func _blot(color: Color) -> void:
	draw_circle(Vector2.ZERO, 24.0, color)
	for i in 5:
		draw_circle(Vector2.from_angle(TAU * i / 5.0 + 0.3) * 20.0, 10.0, color)


func _enemy(center: Vector2, half: float) -> void:
	draw_rect(Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), ENEMY)
	draw_rect(Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), Color("#0f3d1a"), false, 2.5)


func _gem(center: Vector2, r: float) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)]), GOLD)
