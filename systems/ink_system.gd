class_name InkSystem
extends Node2D
## Owns the ink grid and draws it as one texture. Kill splats are painted here;
## trails, bombs, and pulses paint through the grid directly.

const CELL_SIZE := 16.0
const INK_SHADER := preload("res://entities/ground/ink.gdshader")

var grid: InkGrid

var _image: Image
var _texture: ImageTexture
var _sprite: Sprite2D
var _enemies: EnemyManager
var _pending_blasts: Array[Vector3] = []  # x, y, radius


func setup(arena: Rect2, enemies: EnemyManager) -> void:
	_enemies = enemies
	grid = InkGrid.new(arena.size, CELL_SIZE)
	_image = Image.create_from_data(grid.cols, grid.rows, false, Image.FORMAT_RGBA8, grid.pixels)
	_texture = ImageTexture.create_from_image(_image)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = _texture
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.scale = Vector2(CELL_SIZE, CELL_SIZE)
	_sprite.position = arena.position
	var material := ShaderMaterial.new()
	material.shader = INK_SHADER
	_sprite.material = material
	add_child(_sprite)
	Events.enemy_killed.connect(_on_enemy_killed)


## Share of the page covered by the player's ink, 0..1.
func ownership() -> float:
	return float(grid.ink_count) / float(grid.total_cells())


func smudge_share() -> float:
	return float(grid.smudge_count) / float(grid.total_cells())


func _on_enemy_killed(_type_id: String, pos: Vector2, splat_radius: float, _xp: int) -> void:
	var radius := Upgrades.value("splat_size", splat_radius)
	grid.paint_circle(pos, radius, InkGrid.INK)
	# Splat damage (Acid Bath) is applied next frame, so chain reactions
	# spread over frames instead of recursing.
	if Upgrades.bonus("splat_damage") > 0.0:
		_pending_blasts.append(Vector3(pos.x, pos.y, radius))


func _process(_delta: float) -> void:
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
