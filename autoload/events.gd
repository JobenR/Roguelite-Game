extends Node
## Global signal bus. Systems talk through these signals, not direct references.

signal run_started
signal enemy_killed(type_id: String, pos: Vector2, splat_radius: float)
signal player_health_changed(hp: float, max_hp: float)
signal player_died
