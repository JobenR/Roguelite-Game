class_name DebugOverlay
extends Control
## Toggleable debug panel (F3 or the DBG touch button): FPS, counts, timers,
## plus a stress-test button that spawns 300 enemies.

const REFRESH := 0.25

var _enemies: EnemyManager
var _bullets: BulletManager
var _director: SpawnDirector
var _ink: InkSystem
var _panel: PanelContainer
var _label: Label
var _refresh_left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.position = Vector2(0.0, 40.0)
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	box.add_child(_label)
	var burst := Button.new()
	burst.text = "+300 enemies (F2)"
	burst.custom_minimum_size = Vector2(0.0, 44.0)
	burst.pressed.connect(func() -> void: _director.spawn_burst(300))
	box.add_child(burst)
	_panel.visible = false


func setup(enemies: EnemyManager, bullets: BulletManager, director: SpawnDirector, ink: InkSystem) -> void:
	_ink = ink
	_enemies = enemies
	_bullets = bullets
	_director = director


func _process(delta: float) -> void:
	_panel.visible = GameState.debug_visible
	if not _panel.visible or _enemies == null:
		return
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return
	_refresh_left = REFRESH
	_label.text = "FPS %d\nEnemies %d\nBullets %d\nRun time %s\nWave %d, next in %s\nEnemy health x%.2f\nBoss in %s, final in %s\nSpawn every %.2fs\nInk %.1f%%  Smudge %.1f%%" % [
		int(Engine.get_frames_per_second()),
		_enemies.active.size(),
		_bullets.active.size(),
		GameState.format_time(GameState.run_time),
		_director.wave_index + 1,
		("%ds" % int(_director.time_to_next_wave())) if _director.time_to_next_wave() >= 0.0 else "-",
		_director.hp_multiplier(),
		("%ds" % int(_director.time_to_boss())) if _director.time_to_boss() >= 0.0 else "-",
		("%ds" % int(_director.time_to_final())) if _director.time_to_final() >= 0.0 else "-",
		_director.spawn_interval,
		_ink.ownership() * 100.0,
		_ink.smudge_share() * 100.0,
	]
