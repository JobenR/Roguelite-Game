extends Node
## Run-level state shared by all systems.

enum State { PLAYING, DEAD }

var state: State = State.PLAYING
var run_time: float = 0.0
var kills: int = 0
var debug_visible: bool = false


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.player_died.connect(_on_player_died)


func start_run() -> void:
	state = State.PLAYING
	run_time = 0.0
	kills = 0
	Events.run_started.emit()


func is_playing() -> bool:
	return state == State.PLAYING


func _process(delta: float) -> void:
	if state == State.PLAYING:
		run_time += delta
	# Actions are polled, never read from events: touch UI feeds them with
	# Input.action_press(), which does not generate input events.
	if Input.is_action_just_pressed("debug_toggle"):
		debug_visible = not debug_visible


func _on_enemy_killed(_type_id: String, _pos: Vector2, _splat_radius: float) -> void:
	kills += 1


func _on_player_died() -> void:
	state = State.DEAD


static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]
