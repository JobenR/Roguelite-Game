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


func setup(arena: Rect2) -> void:
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


func _on_enemy_killed(_type_id: String, pos: Vector2, splat_radius: float) -> void:
	grid.paint_circle(pos, splat_radius, InkGrid.INK)


func _process(_delta: float) -> void:
	if grid != null and grid.dirty:
		grid.dirty = false
		_image.set_data(grid.cols, grid.rows, false, Image.FORMAT_RGBA8, grid.pixels)
		_texture.update(_image)
