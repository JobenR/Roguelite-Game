class_name Bullet
extends Node2D
## Pooled bullet. State only; BulletManager moves it and resolves hits.

var velocity: Vector2 = Vector2.ZERO
var speed: float = 0.0
var damage: float = 0.0
var radius: float = 0.0
var life: float = 0.0
var pierce_left: int = 0
var ricochet_left: int = 0
var burst_radius: float = 0.0
var hit: Array = []  # enemies already struck, so pierce and ricochet skip them

@onready var visual: Node2D = $Visual


func launch(pos: Vector2, dir: Vector2, weapon: Dictionary) -> void:
	position = pos
	speed = float(weapon.get("bullet_speed", 600.0))
	velocity = dir * speed
	damage = Upgrades.value("damage", float(weapon.get("damage", 5.0)))
	radius = float(weapon.get("bullet_radius", 4.0))
	life = float(weapon.get("bullet_life", 1.0))
	pierce_left = int(Upgrades.bonus("pierce"))
	ricochet_left = int(Upgrades.bonus("ricochet"))
	burst_radius = Upgrades.bonus("explosive") * Upgrades.mult_of("explosive_size")
	hit.clear()
	visual.setup(weapon.get("visual", {}), radius)
