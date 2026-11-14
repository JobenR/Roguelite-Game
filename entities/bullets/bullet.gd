class_name Bullet
extends Node2D
## Pooled bullet. State only; BulletManager moves it and resolves hits.

var weapon: Dictionary = {}
var velocity: Vector2 = Vector2.ZERO
var speed: float = 0.0
var damage: float = 0.0
var radius: float = 0.0
var life: float = 0.0
var pierce_left: int = 0
var ricochet_left: int = 0
var wall_bounces: int = 0
var burst_radius: float = 0.0
var burst_damage_mult: float = 0.3
var homing_rate: float = 0.0
var knockback: float = 0.0
var crit: bool = false
var can_split: bool = false
var paint_left: float = 0.0   # distance until the next Painter's Shots dot
var shed_left: float = 0.0    # time until the next droplet shed in flight
var glow: Color = Color.WHITE
var hit: Array = []  # enemies already struck, so pierce and ricochet skip them

@onready var visual: Node2D = $Visual


func launch(pos: Vector2, dir: Vector2, p_weapon: Dictionary, damage_scale: float = 1.0) -> void:
	weapon = p_weapon
	position = pos
	var heavy := Upgrades.bonus("heavy")
	speed = float(weapon.get("bullet_speed", 600.0)) * Upgrades.mult_of("reach")
	speed *= maxf(0.4, 1.0 + DataDB.arsenal_num("heavy", "speed_per_level", -0.1) * heavy)
	velocity = dir * speed
	damage = Upgrades.value("damage", float(weapon.get("damage", 5.0))) * damage_scale * (1.0 + GameState.damage_bonus)
	damage *= 1.0 + DataDB.arsenal_num("heavy", "damage_per_level", 0.15) * heavy
	rotation = dir.angle()
	radius = float(weapon.get("bullet_radius", 4.0)) * (1.0 + DataDB.arsenal_num("heavy", "radius_per_level", 0.3) * heavy)
	knockback = DataDB.arsenal_num("heavy", "knockback_per_level", 18.0) * heavy
	life = float(weapon.get("bullet_life", 1.0))
	pierce_left = int(Upgrades.bonus("pierce")) + int(weapon.get("pierce_bonus", 0))
	ricochet_left = int(Upgrades.bonus("ricochet"))
	wall_bounces = int(Upgrades.bonus("wall_bounce"))
	burst_radius = Upgrades.bonus("explosive") * Upgrades.mult_of("explosive_size")
	burst_damage_mult = float(weapon.get("burst_damage_mult", 0.3))
	homing_rate = Upgrades.bonus("homing") + float(weapon.get("homing", 0.0))
	can_split = Upgrades.bonus("split") > 0.0 and not bool(weapon.get("no_split", false))
	crit = randf() < Upgrades.bonus("crit")
	if crit:
		damage *= 3.0
		radius *= 1.4
	paint_left = 24.0
	shed_left = randf() * 0.08
	hit.clear()
	var look: Dictionary = weapon.get("visual", {})
	glow = Color("#fbbf24") if crit else Color(String(look.get("glow", "#38bdf8")))
	visual.setup(look, radius)
