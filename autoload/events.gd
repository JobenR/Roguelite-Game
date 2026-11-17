extends Node
## Global signal bus. Systems talk through these signals, not direct references.

signal run_started
## dir is the direction of the killing blow (zero when there is none).
signal enemy_killed(type_id: String, pos: Vector2, splat_radius: float, xp: int, dir: Vector2)
signal player_health_changed(hp: float, max_hp: float)
signal player_died
signal secondary_charge_changed(ratio: float)
signal pulse_charge_changed(ratio: float)
## The Ultimate was released; cells_filled is the ground it flooded.
signal pulse_fired(cells_filled: int)
signal ultimate_ready
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
signal milestone_reached(percent: int, text: String)
## Asks the level-up screen for an extra card pick with this title.
signal bonus_card(title: String)
signal boss_spawned(boss_name: String)
signal boss_health_changed(ratio: float)
signal boss_defeated(boss_name: String)
## A short urgent message for the middle of the screen.
signal alert(text: String, seconds: float)
signal set_bonus(set_name: String, count: int, desc: String)
signal player_hurt
signal shield_changed(value: float, max_value: float)
signal final_boss_defeated
## Number of large enemies (Brutes and bosses) alive; drives the metal music.
signal heavy_presence(count: int)
## Burning Page: a strip has burnt. share is the part of it the player owned.
signal strip_burned(index: int, share: float, xp: int, perfect: bool)
signal items_changed
signal seal_collected(amount: int)
## Masterpiece mode: the player dipped in a well and now carries another ink.
signal ink_changed
