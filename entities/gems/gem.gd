class_name Gem
extends Node2D
## Pooled XP gem. State only; GemManager moves and collects it.

var xp: int = 1
var magnet: bool = false

@onready var visual: Node2D = $Visual


func drop(pos: Vector2, p_xp: int) -> void:
	position = pos
	xp = p_xp
	magnet = false
	visual.setup({"sides": 4, "color": "#fbbf24", "outline": "#7a4a00"}, 8.0)
