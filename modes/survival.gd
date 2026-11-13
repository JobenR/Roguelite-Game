extends Node2D
## Survival mode root. Wires the systems together and starts the run.

const MODE_ID := "survival"

@onready var arena: Arena = $Arena
@onready var enemies: EnemyManager = $EnemyManager
@onready var bullets: BulletManager = $BulletManager
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var director: SpawnDirector = $SpawnDirector
@onready var debug_overlay: DebugOverlay = $UI/SafeArea/DebugOverlay


func _ready() -> void:
	var mode: Dictionary = DataDB.modes.get(MODE_ID, {})
	var rect := Rect2(0.0, 0.0, float(mode.get("arena_width", 3840.0)), float(mode.get("arena_height", 2160.0)))

	arena.setup(rect)
	player.position = rect.get_center()
	enemies.setup(player, rect)
	bullets.setup(enemies, rect)
	player.setup(enemies, bullets, rect)
	director.setup(enemies, player, rect, MODE_ID)
	debug_overlay.setup(enemies, bullets, director)

	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)
	camera.reset_smoothing()

	GameState.start_run()
