class_name Enemy
extends Node2D
## Pooled enemy. Holds state only; EnemyManager moves and resolves all enemies
## in one loop. No physics body and no per-enemy _process.

var type_id: String = ""
var hp: float = 0.0
var max_hp: float = 0.0
var speed: float = 0.0
var radius: float = 0.0
var damage: float = 0.0
var xp: int = 0
var splat_radius: float = 0.0
var active: bool = false

@onready var visual: Node2D = $Visual


func spawn(p_type_id: String, data: Dictionary, pos: Vector2, hp_mult: float) -> void:
	type_id = p_type_id
	max_hp = float(data.get("hp", 10.0)) * hp_mult
	hp = max_hp
	speed = float(data.get("speed", 60.0))
	radius = float(data.get("radius", 12.0))
	damage = float(data.get("damage", 5.0))
	xp = int(data.get("xp", 1))
	splat_radius = float(data.get("splat_radius", radius * 2.0))
	position = pos
	active = true
	visual.setup(data.get("visual", {}), radius)
