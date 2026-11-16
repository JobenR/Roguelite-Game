class_name UpgradeIcon
extends Control
## Draws an upgrade's picture in code, so a card can be recognised without
## reading it. Icons are drawn in a 100x100 space centred on zero. To use art
## instead, replace this control with a TextureRect keyed by the same icon id.

const INK := Color("#141210")
const DARK := Color("#141210")
const LIGHT := Color("#b8ad96")
const WHITE := Color(1, 1, 1)
const ENEMY := Color("#3fbf4f")
const GOLD := Color("#fbbf24")

var icon_id: String = ""
var tint: Color = INK
## One or two letters shown in a corner disc, to tell apart cards that share a picture.
var badge: String = ""
## Card art: a splash of the rarity colour behind the picture. Epic and
## Legendary cards also get slow-turning rays and drifting sparks.
var splash: Color = Color(0, 0, 0, 0)
var fancy: int = 0  # 0 plain, 1 epic, 2 legendary


func _ready() -> void:
	set_process(fancy > 0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y) / 100.0
	if splash.a > 0.0:
		s *= 0.6  # leave room for the splash round the picture
	draw_set_transform(size * 0.5, 0.0, Vector2(s, s))
	var time := Time.get_ticks_msec() * 0.001
	if splash.a > 0.0:
		# Rays behind rare cards, turning slowly.
		if fancy > 0:
			for i in 12:
				var angle := TAU * i / 12.0 + time * 0.25
				var reach := 78.0 if i % 2 == 0 else 62.0
				draw_colored_polygon(PackedVector2Array([Vector2.from_angle(angle - 0.07) * 30.0, Vector2.from_angle(angle) * reach, Vector2.from_angle(angle + 0.07) * 30.0]), Color(splash, 0.22 + 0.1 * fancy))
		# The splash: a bleed halo, a lumpy pool, a streak and flung droplets.
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(icon_id)
		for i in 4:
			draw_circle(Vector2.ZERO, 66.0 - i * 6.0, Color(splash, 0.05 + 0.03 * i))
		for i in 8:
			draw_circle(Vector2(rng.randf_range(-16, 16), rng.randf_range(-14, 14)), rng.randf_range(30.0, 42.0), Color(splash, 0.9))
		var dir := Vector2.from_angle(rng.randf() * TAU)
		for i in 5:
			draw_circle(dir * (44.0 + i * 13.0), 13.0 - i * 2.2, Color(splash, 0.9))
		for i in 16:
			draw_circle(Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(54.0, 92.0), rng.randf_range(1.5, 6.0), Color(splash, 0.85))
		# A pale pool for the picture to sit on, with a wet highlight.
		draw_circle(Vector2.ZERO, 40.0, Color(0.96, 0.93, 0.85, 0.94))
		draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 48, Color(0.08, 0.07, 0.06, 0.9), 3.0)
		draw_arc(Vector2.ZERO, 34.0, 3.6, 4.9, 16, Color(1, 1, 1, 0.8), 3.0)
		if fancy > 0:
			for i in 5 + fancy * 3:
				var orbit := time * (0.5 + 0.13 * i) + i * 1.9
				var at := Vector2.from_angle(orbit) * (56.0 + 14.0 * sin(time * 1.3 + i))
				var size_now := 2.5 + 2.0 * absf(sin(time * 2.0 + i))
				draw_colored_polygon(PackedVector2Array([at + Vector2(0, -size_now * 2.0), at + Vector2(size_now, 0), at + Vector2(0, size_now * 2.0), at + Vector2(-size_now, 0)]), Color(1.0, 0.95, 0.7, 0.9))
		draw_set_transform(size * 0.5, 0.0, Vector2(s, s) * 0.72)
	else:
		# An ink-wash disc with a broken brush ring, in place of a frame.
		draw_circle(Vector2.ZERO, 46.0, Color(0.08, 0.07, 0.06, 0.07))
		draw_arc(Vector2.ZERO, 48.0, 0.5, TAU - 0.25, 48, Color(0.08, 0.07, 0.06, 0.85), 3.5)
		draw_arc(Vector2.ZERO, 44.0, 2.4, 4.6, 24, Color(0.08, 0.07, 0.06, 0.35), 2.0)
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
		"ring_bomb":
			draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 40, INK, 9.0)
			draw_circle(Vector2.ZERO, 11.0, DARK)
			draw_line(Vector2(6, -8), Vector2(14, -20), DARK, 4.0)
			draw_circle(Vector2(16, -23), 4.0, GOLD)
		"forgiving_pulse":
			draw_arc(Vector2.ZERO, 30.0, 0.5, TAU - 0.5, 36, INK, 8.0)
			draw_arc(Vector2.ZERO, 30.0, -0.5, 0.5, 8, GOLD, 5.0)
			draw_circle(Vector2.ZERO, 7.0, INK)
		"permanent_marker":
			_blot(Color("#12235e"))
			draw_rect(Rect2(-11, -2, 22, 17), GOLD)
			draw_arc(Vector2(0, -3), 8.0, PI, TAU, 12, GOLD, 4.0)
		"painter":
			for i in 5:
				draw_circle(Vector2(-36.0 + i * 15.0, 14.0 - i * 6.0), 5.0, Color(INK, 0.5 + i * 0.1))
			_bullet(Vector2(40, -18), 14.0)
		"quicksand":
			draw_line(Vector2(-38, 14), Vector2(38, 14), INK, 20.0)
			_enemy(Vector2(0, 2), 14.0)
			draw_line(Vector2(-22, -24), Vector2(22, -24), DARK, 4.0)
			draw_line(Vector2(-14, -34), Vector2(14, -34), DARK, 4.0)
		"territory_tax":
			draw_rect(Rect2(-32, -6, 64, 34), Color(INK, 0.85))
			draw_rect(Rect2(-32, -6, 64, 34), DARK, false, 3.0)
			_gem(Vector2(0, -22), 12.0)
			_gem(Vector2(-24, -14), 7.0)
			_gem(Vector2(24, -14), 7.0)
		"shockwave":
			draw_circle(Vector2.ZERO, 9.0, INK)
			draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 32, INK, 6.0)
			for i in 8:
				var dir := Vector2.from_angle(TAU * i / 8.0)
				draw_line(dir * 30.0, dir * 42.0, DARK, 5.0)
		"homing":
			var curve := PackedVector2Array()
			for i in 12:
				var t := i / 11.0
				curve.append(Vector2(-38.0 + t * 60.0, 24.0 - sin(t * PI * 0.5) * 44.0))
			draw_polyline(curve, INK, 6.0, true)
			_enemy(Vector2(30, -22), 11.0)
			draw_circle(curve[0], 6.0, DARK)
		"dash":
			_drop(Vector2(18, 2), 16.0, INK)
			for i in 3:
				draw_line(Vector2(-40, -14.0 + i * 14.0), Vector2(-8.0 - i * 4.0, -14.0 + i * 14.0), Color(INK, 0.7), 5.0)
		"mortar":
			var arc := PackedVector2Array()
			for i in 12:
				var t := i / 11.0
				arc.append(Vector2(-36.0 + t * 66.0, 20.0 - sin(t * PI) * 46.0))
			draw_polyline(arc, Color(INK, 0.5), 4.0, true)
			draw_circle(arc[6], 12.0, DARK)
			draw_arc(Vector2(30, 22), 12.0, 0.0, TAU, 20, Color("#dc2626"), 3.0)
		"reroll":
			draw_arc(Vector2.ZERO, 26.0, 0.6, TAU - 0.4, 32, Color("#16a34a"), 7.0)
			draw_colored_polygon(PackedVector2Array([Vector2(30, -22), Vector2(34, 0), Vector2(14, -8)]), Color("#16a34a"))
			draw_rect(Rect2(-9, -12, 18, 24), WHITE)
			draw_rect(Rect2(-9, -12, 18, 24), DARK, false, 3.0)
		"shield":
			var shield := PackedVector2Array([Vector2(-26, -28), Vector2(26, -28), Vector2(26, 2), Vector2(0, 32), Vector2(-26, 2)])
			draw_colored_polygon(shield, INK)
			draw_polyline(PackedVector2Array([shield[0], shield[1], shield[2], shield[3], shield[4], shield[0]]), DARK, 4.0, true)
			draw_line(Vector2(0, -20), Vector2(0, 22), LIGHT, 4.0)
		"snow":
			for i in 3:
				var arm := Vector2.from_angle(PI * i / 3.0) * 32.0
				draw_line(-arm, arm, Color("#0ea5e9"), 6.0)
				for tip: Vector2 in [arm, -arm]:
					draw_circle(tip, 5.0, Color("#7dd3fc"))
			draw_circle(Vector2.ZERO, 8.0, WHITE)
		"skull":
			draw_circle(Vector2(0, -6), 26.0, WHITE)
			draw_rect(Rect2(-14, 12, 28, 16), WHITE)
			draw_arc(Vector2(0, -6), 26.0, 0.0, TAU, 28, DARK, 3.5)
			draw_circle(Vector2(-10, -8), 7.0, DARK)
			draw_circle(Vector2(10, -8), 7.0, DARK)
			for i in 3:
				draw_line(Vector2(-8.0 + i * 8.0, 14), Vector2(-8.0 + i * 8.0, 28), DARK, 3.0)
		"bolt":
			draw_colored_polygon(PackedVector2Array([Vector2(8, -38), Vector2(-20, 4), Vector2(-2, 4), Vector2(-10, 38), Vector2(22, -8), Vector2(4, -8)]), GOLD)
			draw_polyline(PackedVector2Array([Vector2(8, -38), Vector2(-20, 4), Vector2(-2, 4), Vector2(-10, 38), Vector2(22, -8), Vector2(4, -8), Vector2(8, -38)]), Color("#92400e"), 3.0, true)
		"flame":
			draw_colored_polygon(PackedVector2Array([Vector2(0, -38), Vector2(22, -4), Vector2(18, 22), Vector2(0, 34), Vector2(-18, 22), Vector2(-22, -4), Vector2(-8, -14)]), Color("#f97316"))
			draw_colored_polygon(PackedVector2Array([Vector2(0, -12), Vector2(11, 8), Vector2(8, 24), Vector2(0, 30), Vector2(-8, 24), Vector2(-11, 8)]), GOLD)
		"mine":
			draw_circle(Vector2.ZERO, 22.0, DARK)
			for i in 8:
				var spike := Vector2.from_angle(TAU * i / 8.0)
				draw_line(spike * 20.0, spike * 33.0, DARK, 6.0)
			draw_circle(Vector2.ZERO, 8.0, Color("#ef4444"))
		"turret":
			draw_rect(Rect2(-22, 8, 44, 18), DARK)
			draw_circle(Vector2(0, 0), 20.0, INK)
			draw_arc(Vector2(0, 0), 20.0, 0.0, TAU, 24, DARK, 3.5)
			draw_line(Vector2(6, -8), Vector2(34, -30), DARK, 9.0)
			draw_circle(Vector2(0, 0), 7.0, LIGHT)
		"boomerang":
			draw_polyline(PackedVector2Array([Vector2(-30, 24), Vector2(-4, -22), Vector2(32, -14)]), INK, 14.0, true)
			draw_polyline(PackedVector2Array([Vector2(-30, 24), Vector2(-4, -22), Vector2(32, -14)]), LIGHT, 3.0, true)
			draw_arc(Vector2(4, 8), 30.0, 0.4, 2.4, 16, Color(INK, 0.4), 3.0)
		"wave":
			for k in 3:
				var crest := PackedVector2Array()
				for i in 13:
					crest.append(Vector2(-38.0 + i * 6.3, -16.0 + k * 16.0 + sin(i * 1.05) * 8.0))
				draw_polyline(crest, Color(INK, 1.0 - k * 0.28), 8.0 - k, true)
		"rain":
			for d: Vector2 in [Vector2(-22, -18), Vector2(4, -26), Vector2(26, -8), Vector2(-10, 10), Vector2(16, 20)]:
				_drop(d, 8.0, INK)
		"plane":
			draw_colored_polygon(PackedVector2Array([Vector2(36, -6), Vector2(-34, -30), Vector2(-14, -2), Vector2(-34, 26)]), WHITE)
			draw_polyline(PackedVector2Array([Vector2(36, -6), Vector2(-34, -30), Vector2(-14, -2), Vector2(-34, 26), Vector2(36, -6)]), DARK, 3.5, true)
			draw_line(Vector2(36, -6), Vector2(-14, -2), DARK, 3.0)
		"saw":
			var teeth := PackedVector2Array()
			for i in 20:
				teeth.append(Vector2.from_angle(TAU * i / 20.0) * (36.0 if i % 2 == 0 else 25.0))
			draw_colored_polygon(teeth, DARK)
			draw_circle(Vector2.ZERO, 15.0, LIGHT)
			draw_circle(Vector2.ZERO, 5.0, DARK)
		"hole":
			draw_circle(Vector2.ZERO, 18.0, Color("#0b0420"))
			for k in 3:
				draw_arc(Vector2.ZERO, 24.0 + k * 7.0, k * 1.4, k * 1.4 + 3.6, 20, Color("#7c3aed"), 4.0)
			draw_circle(Vector2(30, -22), 4.0, ENEMY)
			draw_circle(Vector2(-28, 20), 4.0, ENEMY)
		"book":
			draw_colored_polygon(PackedVector2Array([Vector2(-34, -22), Vector2(0, -14), Vector2(0, 26), Vector2(-34, 18)]), WHITE)
			draw_colored_polygon(PackedVector2Array([Vector2(34, -22), Vector2(0, -14), Vector2(0, 26), Vector2(34, 18)]), Color("#e7e5e4"))
			draw_polyline(PackedVector2Array([Vector2(-34, -22), Vector2(0, -14), Vector2(34, -22), Vector2(34, 18), Vector2(0, 26), Vector2(-34, 18), Vector2(-34, -22)]), DARK, 3.5, true)
			draw_line(Vector2(0, -14), Vector2(0, 26), DARK, 3.0)
			_gem(Vector2(0, -30), 8.0)
		"cards":
			for k in 3:
				var off := Vector2(-16.0 + k * 16.0, 6.0 - k * 6.0)
				draw_rect(Rect2(off.x - 14, off.y - 22, 28, 40), WHITE)
				draw_rect(Rect2(off.x - 14, off.y - 22, 28, 40), DARK, false, 3.0)
			draw_circle(Vector2(16, -8), 6.0, GOLD)
		"flower":
			for k in 6:
				draw_circle(Vector2.from_angle(TAU * k / 6.0) * 18.0, 12.0, INK)
			draw_circle(Vector2.ZERO, 10.0, GOLD)
			draw_line(Vector2(0, 22), Vector2(0, 40), Color("#15803d"), 5.0)
		"bomb":
			draw_circle(Vector2(-2, 6), 26.0, DARK)
			draw_circle(Vector2(-12, -4), 7.0, Color("#5b7fd6"))
			draw_line(Vector2(12, -16), Vector2(24, -30), Color("#78716c"), 5.0)
			draw_circle(Vector2(26, -33), 6.0, GOLD)
		"star":
			var star := PackedVector2Array()
			for i in 10:
				star.append(Vector2.from_angle(-PI / 2.0 + TAU * i / 10.0) * (36.0 if i % 2 == 0 else 15.0))
			draw_colored_polygon(star, GOLD)
			draw_circle(Vector2.ZERO, 7.0, WHITE)
		"whip":
			draw_arc(Vector2(-18, 14), 44.0, -1.5, 0.3, 20, INK, 12.0)
			draw_arc(Vector2(-18, 14), 44.0, -1.5, 0.3, 20, LIGHT, 3.0)
			draw_circle(Vector2(-18, 14), 9.0, DARK)
		"stamp":
			draw_rect(Rect2(-9, -34, 18, 26), DARK)
			draw_rect(Rect2(-24, -10, 48, 14), INK)
			draw_rect(Rect2(-24, -10, 48, 14), DARK, false, 3.0)
			draw_rect(Rect2(-22, 14, 44, 16), Color(INK, 0.45))
		_:
			_drop(Vector2.ZERO, 24.0, INK)
	if badge != "":
		var font := ThemeDB.fallback_font
		draw_circle(Vector2(32, 32), 15.0, WHITE)
		draw_arc(Vector2(32, 32), 15.0, 0.0, TAU, 20, Color("#c1272d"), 3.0)
		var width := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, Vector2(32.0 - width * 0.5, 37.5), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, DARK)


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
