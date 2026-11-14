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
var burst_damage_mult: float = 0.3
var paint_left: float = 0.0   # distance until the next Painter's Shots dot
var shed_left: float = 0.0    # time until the next droplet shed in flight
var glow: Color = Color.WHITE
var hit: Array = []  # enemies already struck, so pierce and ricochet skip them

@onready var visual: Node2D = $Visual


func launch(pos: Vector2, dir: Vector2, weapon: Dictionary, damage_scale: float = 1.0) -> void:
	position = pos
	speed = float(weapon.get("bullet_speed", 600.0))
	velocity = dir * speed
	damage = Upgrades.value("damage", float(weapon.get("damage", 5.0))) * damage_scale
	rotation = dir.angle()
	radius = float(weapon.get("bullet_radius", 4.0))
	life = float(weapon.get("bullet_life", 1.0))
	pierce_left = int(Upgrades.bonus("pierce"))
	ricochet_left = int(Upgrades.bonus("ricochet"))
	burst_radius = Upgrades.bonus("explosive") * Upgrades.mult_of("explosive_size")
	burst_damage_mult = float(weapon.get("burst_damage_mult", 0.3))
	paint_left = 24.0
	shed_left = randf() * 0.08
	hit.clear()
	var look: Dictionary = weapon.get("visual", {})
	glow = Color(String(look.get("glow", "#38bdf8")))
	visual.setup(look, radius)
