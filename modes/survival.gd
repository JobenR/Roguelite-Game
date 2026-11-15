extends Node2D
## Survival mode root. Wires the systems together and starts the run.


@onready var arena: Arena = $Arena
@onready var ink: InkSystem = $Ink
@onready var effects: Effects = $Effects
@onready var secondary: SecondarySystem = $Secondary
@onready var pulse: PulseSystem = $PulseSystem
@onready var enemies: EnemyManager = $EnemyManager
@onready var bullets: BulletManager = $BulletManager
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var director: SpawnDirector = $SpawnDirector
@onready var hazards: Hazards = $Hazards
@onready var arsenal: Arsenal = $Arsenal
@onready var enemy_shots: EnemyShots = $EnemyShots
@onready var glyphs: GlyphSystem = $GlyphSystem
@onready var milestones: MilestoneSystem = $MilestoneSystem
@onready var aux: AuxWeapons = $AuxWeapons
@onready var pickups: PickupManager = $PickupManager
@onready var gems: GemManager = $GemManager
@onready var levelup: Control = $UI/LevelUpCards
@onready var pause_menu: Control = $UI/PauseMenu
@onready var run_summary: Control = $UI/RunSummary
@onready var hud: Control = $UI/SafeArea/HUD
@onready var debug_overlay: DebugOverlay = $UI/SafeArea/DebugOverlay


func _ready() -> void:
	var mode_id := GameState.mode_id if DataDB.modes.has(GameState.mode_id) else "survival"
	var mode: Dictionary = DataDB.modes.get(mode_id, {})
	var rect := Rect2(0.0, 0.0, float(mode.get("arena_width", 3840.0)), float(mode.get("arena_height", 2160.0)))

	arena.setup(rect)
	player.position = rect.get_center()
	ink.setup(rect, enemies, float(mode.get("ink_cell_size", 8.0)))
	enemies.setup(player, rect, ink, effects, enemy_shots)
	enemy_shots.setup(player, ink, rect)
	bullets.setup(enemies, rect, effects, ink)
	player.setup(enemies, bullets, rect, ink, effects)
	hazards.setup(enemies, ink, effects)
	secondary.setup(player, enemies, ink, effects, hazards)
	arsenal.setup(player, enemies, bullets, ink, effects, hazards, secondary)
	glyphs.setup(player, enemies, ink, effects)
	pulse.setup(player, enemies, ink, effects, glyphs, hazards)
	milestones.setup(ink, player, pulse)
	gems.setup(player)
	aux.setup(player, enemies, ink, effects)
	pickups.setup(player, effects)
	pause_menu.setup(levelup)
	director.setup(enemies, player, rect, mode_id)
	debug_overlay.setup(enemies, bullets, director, ink)
	hud.setup(ink, milestones)

	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)
	# Phones show the same view on a far smaller screen, so zoom in there to
	# keep the brushwork and the enemies a readable size.
	var touch := DisplayServer.is_touchscreen_available()
	var zoom := float(mode.get("camera_zoom_touch" if touch else "camera_zoom", 1.0))
	camera.zoom = Vector2(zoom, zoom)
	camera.reset_smoothing()
	run_summary.setup(ink)

	# Burning Page: add the fire and the routing it needs.
	if mode.has("burn"):
		var flow := FlowField.new(ink.grid)
		var burn := BurnSystem.new()
		burn.name = "BurnSystem"
		add_child(burn)
		move_child(burn, ink.get_index() + 1)
		burn.setup(player, enemies, ink, effects, flow, mode["burn"])
		enemies.flow = flow
		director.burn = burn
		director.ink = ink
		debug_overlay.burn = burn

	GameState.start_run()
