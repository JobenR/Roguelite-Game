class_name Gem
extends Node2D
## Pooled XP gem. State only; GemManager moves and collects it.

var xp: int = 1
var magnet: bool = false
var seals: int = 0  # above zero: this is a Seal, not an XP gem

@onready var visual: Node2D = $Visual


func drop(pos: Vector2, p_xp: int, p_seals: int = 0) -> void:
	position = pos
	xp = p_xp
	seals = p_seals
	magnet = false
	if seals > 0:
		# A red seal stamp, larger than a gem, so it reads as a different reward.
		visual.setup({"sides": 4, "rotation_deg": 45, "color": "#c1272d", "outline": "#5c0d12", "halo": "#ff5a5a", "seal": "#efe6d2", "shadow": false}, 13.0)
		return
	visual.setup({"sides": 4, "color": "#e0a826", "outline": "#5c3a00", "halo": "#f5c542", "shadow": false}, 8.0)
