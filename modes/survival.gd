extends Node2D
## Survival mode root. Wires the systems together and starts the run.

const MODE_ID := "survival"

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
@onready var aux: AuxWeapons = $AuxWeapons
@onready var pickups: PickupManager = $PickupManager
@onready var gems: GemManager = $GemManager
@onready var levelup: Control = $UI/LevelUpCards
@onready var pause_menu: Control = $UI/PauseMenu
@onready var hud: Control = $UI/SafeArea/HUD
@onready var debug_overlay: DebugOverlay = $UI/SafeArea/DebugOverlay


func _ready() -> void:
	var mode: Dictionary = DataDB.modes.get(MODE_ID, {})
	var rect := Rect2(0.0, 0.0, float(mode.get("arena_width", 3840.0)), float(mode.get("arena_height", 2160.0)))

	arena.setup(rect)
	player.position = rect.get_center()
	ink.setup(rect, enemies, float(mode.get("ink_cell_size", 8.0)))
	enemies.setup(player, rect, ink, effects)
	bullets.setup(enemies, rect, effects, ink)
	player.setup(enemies, bullets, rect, ink, effects)
	secondary.setup(player, enemies, ink, effects)
	pulse.setup(player, enemies, ink, effects)
	gems.setup(player)
	aux.setup(player, enemies, ink, effects)
	pickups.setup(player, effects)
	pause_menu.setup(levelup)
	director.setup(enemies, player, rect, MODE_ID)
	debug_overlay.setup(enemies, bullets, director, ink)
	hud.setup(ink)

	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)
	camera.reset_smoothing()

	GameState.start_run()
