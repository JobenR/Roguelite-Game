extends Node
## Global signal bus. Systems talk through these signals, not direct references.

signal run_started
## dir is the direction of the killing blow (zero when there is none).
signal enemy_killed(type_id: String, pos: Vector2, splat_radius: float, xp: int, dir: Vector2)
signal player_health_changed(hp: float, max_hp: float)
signal player_died
signal secondary_charge_changed(ratio: float)
signal pulse_charge_changed(ratio: float)
## cells_filled is 0 when the pulse found no closed shape and fizzled.
signal pulse_fired(cells_filled: int)
signal xp_collected(amount: int)
signal xp_changed(xp: int, xp_to_next: int, level: int)
signal level_up(level: int)
signal upgrade_applied(id: String)
signal synergy_unlocked(synergy_name: String, desc: String)
signal wave_started(index: int)
## number is the 1-based wave about to start.
signal wave_warning(number: int, seconds: float, label: String)
signal power_granted(id: String, seconds: float)
signal screen_shake(amount: float)
signal dash_charge_changed(ratio: float)
signal glyph_triggered(kind: String, scale: float)
signal milestone_reached(percent: int, text: String)
## Asks the level-up screen for an extra card pick with this title.
signal bonus_card(title: String)
signal boss_spawned(boss_name: String)
signal boss_health_changed(ratio: float)
signal boss_defeated(boss_name: String)
## A short urgent message for the middle of the screen.
signal alert(text: String, seconds: float)
