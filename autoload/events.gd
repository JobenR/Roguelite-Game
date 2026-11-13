extends Node
## Global signal bus. Systems talk through these signals, not direct references.

signal run_started
signal enemy_killed(type_id: String, pos: Vector2, splat_radius: float)
signal player_health_changed(hp: float, max_hp: float)
signal player_died
signal secondary_charge_changed(ratio: float)
signal pulse_charge_changed(ratio: float)
## cells_filled is 0 when the pulse found no closed shape and fizzled.
signal pulse_fired(cells_filled: int)
