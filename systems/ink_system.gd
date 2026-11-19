class_name InkSystem
extends Node2D
## Owns the ink grid and draws it as one texture. Kill splats are painted here;
## trails, bombs, and pulses paint through the grid directly.

const INK_SHADER := preload("res://entities/ground/ink.gdshader")

var grid: InkGrid
var cell_size: float = 8.0

var _image: Image
var _texture: ImageTexture
var _sprite: Sprite2D
var _bleed_image: Image
var _bleed_texture: ImageTexture
var _paint_image: Image
var _paint_texture: ImageTexture
var _target_texture: ImageTexture
var _enemies: EnemyManager
var _pending_blasts: Array[Vector3] = []  # x, y, radius
var _tax_left: float = 10.0


func setup(arena: Rect2, enemies: EnemyManager, p_cell_size: float) -> void:
	_enemies = enemies
	cell_size = p_cell_size
	grid = InkGrid.new(arena.size, cell_size)
	_image = Image.create_from_data(grid.cols, grid.rows, false, Image.FORMAT_RGBA8, grid.pixels)
	_texture = ImageTexture.create_from_image(_image)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = _texture
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.scale = Vector2(cell_size, cell_size)
	_sprite.position = arena.position
	var material := ShaderMaterial.new()
	material.shader = INK_SHADER
	material.set_shader_parameter("grid_size", Vector2(grid.cols, grid.rows))
	# The page is painted in the chosen ink; pulse fills are a paler shade of it.
	material.set_shader_parameter("ink_color", Color(GameState.ink_color, 0.94))
	material.set_shader_parameter("ink_light", GameState.ink_light)
	material.set_shader_parameter("glow_color", Color(GameState.ink_light.lerp(Color.WHITE, 0.35), 0.92))
	material.set_shader_parameter("locked_color", Color(GameState.ink_color.darkened(0.45), 0.95))
	var reclaim: Dictionary = DataDB.modes.get(GameState.mode_id, {}).get("reclaim", {})
	if not reclaim.is_empty():
		material.set_shader_parameter("reclaim_look", true)
		material.set_shader_parameter("wall_look", true)
		material.set_shader_parameter("enemy_color", Color(String(reclaim.get("enemy_color", "#ff3d8b")), 0.95))
		material.set_shader_parameter("enemy_light", Color(String(reclaim.get("enemy_light", "#ffb3d1"))))
	_bleed_image = Image.create_from_data(grid.bleed_cols, grid.bleed_rows, false, Image.FORMAT_L8, grid.bleed)
	_bleed_texture = ImageTexture.create_from_image(_bleed_image)
	material.set_shader_parameter("bleed_tex", _bleed_texture)
	material.set_shader_parameter("bleed_scale", Vector2(float(grid.cols) / (grid.bleed_cols * InkGrid.BLEED_SCALE), float(grid.rows) / (grid.bleed_rows * InkGrid.BLEED_SCALE)))
	_sprite.material = material
	add_child(_sprite)
	Events.enemy_killed.connect(_on_enemy_killed)


## Paint by number: hands the shader the per-cell colours and the picture.
func start_paint() -> void:
	var material := _sprite.material as ShaderMaterial
	_paint_image = Image.create_from_data(grid.cols, grid.rows, false, Image.FORMAT_RGB8, grid.paint_pixels)
	_paint_texture = ImageTexture.create_from_image(_paint_image)
	var goal := PackedByteArray()
	goal.resize(grid.cols * grid.rows * 4)
	for i in grid.cols * grid.rows:
		var c := grid.palette[grid.target[i]] if grid.target[i] != 0 else Color.BLACK
		goal[i * 4] = c.r8
		goal[i * 4 + 1] = c.g8
		goal[i * 4 + 2] = c.b8
		goal[i * 4 + 3] = grid.region[i] * 6   # spread the ids so neighbours differ clearly
	_target_texture = ImageTexture.create_from_image(Image.create_from_data(grid.cols, grid.rows, false, Image.FORMAT_RGBA8, goal))
	material.set_shader_parameter("paint_on", true)
	material.set_shader_parameter("paint_tex", _paint_texture)
	material.set_shader_parameter("target_tex", _target_texture)


## Share of the page covered by the player's ink, 0..1.
func ownership() -> float:
	# Burnt paper is out of play, so the share is of what is left.
	return float(grid.ink_count) / float(maxi(1, grid.total_cells() - grid.dead_count))


## The whole page as a small framed picture, drawn with the same ink shader.
## Shown on the end screen as the painting the run produced.
func make_painting(width: float) -> Control:
	var frame := PanelContainer.new()
	var mount := StyleBoxFlat.new()
	mount.bg_color = Color("#efe6d2")
	mount.border_color = Color("#141210")
	mount.set_border_width_all(5)
	mount.set_content_margin_all(10)
	frame.add_theme_stylebox_override("panel", mount)
	var picture := TextureRect.new()
	picture.texture = _texture
	picture.material = _sprite.material
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.custom_minimum_size = Vector2(width, width * grid.rows / grid.cols)
	frame.add_child(picture)
	return frame


func enemy_share() -> float:
	return grid.enemy_share()


func smudge_share() -> float:
	return float(grid.smudge_count) / float(grid.total_cells())


func _on_enemy_killed(_type_id: String, pos: Vector2, splat_radius: float, _xp: int, dir: Vector2) -> void:
	var radius := Upgrades.value("splat_size", splat_radius)
	# Chain Splat: bigger when the kill happens on your own ink.
	if grid.is_ink(pos):
		radius *= 1.0 + Upgrades.bonus("chain_splat")
	# Reclaim: a kill on smudge wipes the smudge around it.
	var reclaim := Upgrades.bonus("reclaim")
	if reclaim > 0.0 and grid.state_at(pos) == InkGrid.SMUDGE:
		grid.clean_circle(pos, radius * (1.5 + reclaim))
	# Masterpiece: a kill inside a numbered area splats that area's own colour,
	# whatever ink the player carries, and stays inside the area.
	var area := int(grid.region[grid.cell_index(pos)]) if grid.paint_on else 0
	if area != 0:
		var carried := grid.current_tint
		grid.current_tint = int(grid.region_target[area])
		grid.clip_region = area
		splat(pos, radius, dir)
		grid.clip_region = 0
		grid.current_tint = carried
	else:
		splat(pos, radius, dir)
	var sticky := Upgrades.bonus("sticky")
	if sticky > 0.0:
		_enemies.slow_area(pos, radius, sticky + 0.15, DataDB.arsenal_num("sticky_splats", "seconds", 2.0))
	# Splat damage (Acid Bath) is applied next frame, so chain reactions
	# spread over frames instead of recursing.
	if Upgrades.bonus("splat_damage") > 0.0:
		_pending_blasts.append(Vector3(pos.x, pos.y, radius))


## An irregular ink splat. With a direction it throws a streak and droplets
## that way, like ink flung by the hit; without one it bursts evenly.
func splat(pos: Vector2, radius: float, dir: Vector2) -> void:
	var directed := dir.length_squared() > 0.01
	grid.paint_circle(pos + _jitter(radius * 0.15), radius * randf_range(0.5, 0.65), InkGrid.INK)
	# Lobes make the core lumpy instead of a perfect disc.
	for i in 3:
		grid.paint_circle(pos + _jitter(radius * 0.5), radius * randf_range(0.25, 0.4), InkGrid.INK)
	if directed:
		# Streak: shrinking blobs thrown along the hit direction.
		var side := dir.orthogonal()
		var reach := radius * randf_range(1.4, 2.2)
		var blobs := 4
		for i in blobs:
			var t := float(i + 1) / blobs
			var p := pos + dir * reach * t + side * randf_range(-0.12, 0.12) * radius
			grid.paint_circle(p, radius * 0.4 * (1.0 - t * 0.7), InkGrid.INK)
	# Droplets: small flecks, mostly ahead of the hit.
	for i in randi_range(8, 14):
		var angle := randf() * TAU
		if directed:
			angle = dir.angle() + randfn(0.0, 0.7)
		var dist := radius * randf_range(0.9, 2.6)
		grid.paint_circle(pos + Vector2.from_angle(angle) * dist, randf_range(cell_size * 0.5, radius * 0.2), InkGrid.INK)


func _jitter(amount: float) -> Vector2:
	return Vector2(randf_range(-amount, amount), randf_range(-amount, amount))


func _process(delta: float) -> void:
	var tax := Upgrades.bonus("territory_tax")
	if tax > 0.0 and GameState.is_playing():
		_tax_left -= delta
		if _tax_left <= 0.0:
			_tax_left = 10.0
			# XP per percent of the page owned.
			GameState.add_xp(int(round(ownership() * 100.0 * tax)))
	if not _pending_blasts.is_empty() and GameState.is_playing():
		var blasts := _pending_blasts.duplicate()
		_pending_blasts.clear()
		var splat_damage := Upgrades.bonus("splat_damage")
		for blast in blasts:
			_enemies.damage_area(Vector2(blast.x, blast.y), blast.z, splat_damage)
	if grid != null and grid.dirty:
		grid.dirty = false
		_image.set_data(grid.cols, grid.rows, false, Image.FORMAT_RGBA8, grid.pixels)
		_texture.update(_image)
		_bleed_image.set_data(grid.bleed_cols, grid.bleed_rows, false, Image.FORMAT_L8, grid.bleed)
		_bleed_texture.update(_bleed_image)
		if grid.paint_dirty and _paint_texture != null:
			grid.paint_dirty = false
			_paint_image.set_data(grid.cols, grid.rows, false, Image.FORMAT_RGB8, grid.paint_pixels)
			_paint_texture.update(_paint_image)
