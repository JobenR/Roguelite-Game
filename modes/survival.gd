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
@onready var milestones: MilestoneSystem = $MilestoneSystem
@onready var item_system: ItemSystem = $ItemSystem
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
	# Cards, pickups and a few UI words are reworded per mode.
	DataDB.apply_mode_text(mode_id)
	var rect := Rect2(0.0, 0.0, float(mode.get("arena_width", 3840.0)), float(mode.get("arena_height", 2160.0)))
	# Reclaim pages each have their own size.
	var page: Dictionary = {}
	if mode.has("reclaim"):
		GameState.reclaim_level = clampi(GameState.reclaim_level, 0, ReclaimSystem.level_count() - 1)
		page = ReclaimSystem.level_data(GameState.reclaim_level)
		rect = Rect2(0.0, 0.0, float(page["arena"][0]), float(page["arena"][1]))

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
	pulse.setup(player, enemies, ink, effects, hazards)
	item_system.setup(player, enemies, effects)
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

	# Masterpiece: lay out the picture and its ink wells. Done before the run
	# starts, because it decides which ink the player begins with.
	if mode.has("paint"):
		var paint := PaintSystem.new()
		paint.name = "PaintSystem"
		add_child(paint)
		move_child(paint, ink.get_index() + 1)
		paint.setup(player, ink, effects, director, rect, mode["paint"])
		run_summary.paint = paint
		hud.paint = paint

	# Reclaim: walls, ink sources, the creeping ink and the race.
	if mode.has("reclaim"):
		var reclaim := ReclaimSystem.new()
		reclaim.name = "ReclaimSystem"
		add_child(reclaim)
		move_child(reclaim, ink.get_index() + 1)
		reclaim.setup(player, ink, enemies, effects, director, mode["reclaim"], GameState.reclaim_level)
		camera.reset_smoothing()
		run_summary.reclaim = reclaim
		hud.reclaim = reclaim
		var race := preload("res://ui/hud/race_bar.gd").new()
		race.reclaim = reclaim
		race.ink = ink
		hud.add_child(race)
		var compass := preload("res://ui/hud/compass.gd").new()
		compass.reclaim = reclaim
		hud.add_child(compass)

	GameState.start_run()
	if mode.has("paint"):
		Events.ink_changed.emit()
	# Head Start (a store item): three free cards as the run begins.
	if bool(SaveData.data.get("use_head_start", true)) and SaveData.use_item("head_start"):
		for i in 3:
			Events.bonus_card.emit.call_deferred("HEAD START: CARD %d OF 3" % (i + 1))
