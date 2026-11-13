class_name Bullet
extends Node2D
## Pooled bullet. State only; BulletManager moves it and checks hits.

var velocity: Vector2 = Vector2.ZERO
var damage: float = 0.0
var radius: float = 0.0
var life: float = 0.0

@onready var visual: Node2D = $Visual


func launch(pos: Vector2, dir: Vector2, weapon: Dictionary) -> void:
	position = pos
	velocity = dir * float(weapon.get("bullet_speed", 600.0))
	damage = float(weapon.get("damage", 5.0))
	radius = float(weapon.get("bullet_radius", 4.0))
	life = float(weapon.get("bullet_life", 1.0))
	visual.setup(weapon.get("visual", {}), radius)
