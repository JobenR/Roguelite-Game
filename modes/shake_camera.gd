extends Camera2D
## Camera with decaying screen shake, driven by Events.screen_shake.

const DECAY := 9.0
const MAX_SHAKE := 14.0

var _shake: float = 0.0


func _ready() -> void:
	Events.screen_shake.connect(func(amount: float) -> void: _shake = minf(MAX_SHAKE, maxf(_shake, amount)))


func _process(delta: float) -> void:
	if _shake <= 0.05:
		offset = Vector2.ZERO
		return
	offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	_shake = lerpf(_shake, 0.0, minf(1.0, DECAY * delta))
