class_name Enemy
extends Node2D
## Pooled enemy. Holds state only; EnemyManager moves and resolves all enemies
## in one loop. No physics body and no per-enemy _process.

enum Behavior { CHASE, CHARGE, RANGED, BOSS }

var type_id: String = ""
var display_name: String = ""
var data: Dictionary = {}
var hp: float = 0.0
var max_hp: float = 0.0
var speed: float = 0.0
var radius: float = 0.0
var damage: float = 0.0
var xp: int = 0
var splat_radius: float = 0.0
var trail_interval: float = 0.0
var trail_radius: float = 0.0
var trail_left: float = 0.0
var ink_cut_chance: float = 1.0
var last_hit_dir: Vector2 = Vector2.ZERO
var color: Color = Color.WHITE
var active: bool = false

var behavior: Behavior = Behavior.CHASE
var heavy: bool = false      # shrugs off knockback, pulls, and crowd pushing
var is_boss: bool = false
var face_move: bool = false  # the visual turns to face the direction of travel
# Ability state, shared by the charge, ranged and boss behaviours.
var ability_state: int = 0
var ability_left: float = 0.0
var ability_dir: Vector2 = Vector2.ZERO
var aux_left: float = 0.0
# Status effects applied by the player's upgrades.
var slow_left: float = 0.0
var slow_amount: float = 0.0
var stain_left: float = 0.0
var stain_amount: float = 0.0
var bleed_left: float = 0.0
var bleed_dps: float = 0.0
var was_on_ink: bool = false
# Approach style: each enemy curves in from its own side and weaves a little,
# so a horde spreads out instead of forming one line.
var flank: float = 0.0
var weave_phase: float = 0.0

@onready var visual: Node2D = $Visual


func spawn(p_type_id: String, p_data: Dictionary, pos: Vector2, hp_mult: float) -> void:
	type_id = p_type_id
	data = p_data
	display_name = String(data.get("name", type_id))
	max_hp = float(data.get("hp", 10.0)) * hp_mult
	hp = max_hp
	speed = float(data.get("speed", 60.0))
	radius = float(data.get("radius", 12.0))
	damage = float(data.get("damage", 5.0))
	xp = int(data.get("xp", 1))
	splat_radius = float(data.get("splat_radius", radius * 2.0))
	trail_interval = float(data.get("trail_interval", 0.5))
	trail_radius = float(data.get("trail_radius", 0.0))
	trail_left = randf() * trail_interval
	ink_cut_chance = float(data.get("ink_cut_chance", 1.0))
	heavy = bool(data.get("heavy", false))
	is_boss = bool(data.get("boss", false))
	face_move = bool(data.get("face_move", false))
	match String(data.get("behavior", "chase")):
		"charge":
			behavior = Behavior.CHARGE
			ability_left = randf_range(1.0, float(data.get("charge_cooldown", 5.0)))
		"ranged":
			behavior = Behavior.RANGED
			ability_left = randf_range(0.5, float(data.get("shot_interval", 2.5)))
		"boss":
			behavior = Behavior.BOSS
			ability_left = float(data.get("slam_cooldown", 6.0))
		_:
			behavior = Behavior.CHASE
	ability_state = 0
	ability_dir = Vector2.ZERO
	aux_left = 0.0
	var spread := float(data.get("flank", 0.0))
	flank = randf_range(-spread, spread)
	weave_phase = randf() * TAU
	slow_left = 0.0
	stain_left = 0.0
	bleed_left = 0.0
	was_on_ink = false
	last_hit_dir = Vector2.ZERO
	var look: Dictionary = data.get("visual", {})
	color = Color(String(look.get("color", "#ffffff")))
	position = pos
	active = true
	visual.rotation = 0.0
	visual.setup(look, radius)
