class_name MilestoneSystem
extends Node
## Ink milestones: the first time the player's share of the page reaches each
## threshold in data/milestones.json, a one-time reward is paid. Losing ground
## later never takes a reward back.

const CHECK_INTERVAL := 0.25

var next_index: int = 0

var _ink: InkSystem
var _player: Player
var _pulse: PulseSystem
var _list: Array = []
var _check_left: float = 0.0


func setup(ink: InkSystem, player: Player, pulse: PulseSystem) -> void:
	_ink = ink
	_player = player
	_pulse = pulse
	_list = DataDB.milestones.get("milestones", [])


## Percent needed for the next milestone, or -1 when all are claimed.
func next_percent() -> int:
	if next_index >= _list.size():
		return -1
	return int(_list[next_index].get("percent", 100))


func _process(delta: float) -> void:
	if _ink == null or not GameState.is_playing():
		return
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK_INTERVAL
	var percent := _ink.ownership() * 100.0
	# One milestone per check, so stacked rewards arrive one at a time.
	if next_index < _list.size() and percent >= float(_list[next_index].get("percent", 100)):
		var milestone: Dictionary = _list[next_index]
		next_index += 1
		_pay(milestone)


func _pay(milestone: Dictionary) -> void:
	var percent := int(milestone.get("percent", 0))
	match String(milestone.get("reward", "")):
		"heal":
			_player.heal(float(milestone.get("amount", 20.0)))
		"pulse":
			_pulse.fill_charge()
		"xp":
			GameState.add_xp(int(milestone.get("amount", 10)))
		"card":
			Events.bonus_card.emit("INK %d%%: BONUS UPGRADE" % percent)
	Events.milestone_reached.emit(percent, String(milestone.get("text", "")))
