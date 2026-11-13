extends Node
## Loads every JSON data file once at startup. Content lives in res://data.

var enemies: Dictionary = {}
var weapons: Dictionary = {}
var player: Dictionary = {}
var modes: Dictionary = {}
var waves: Dictionary = {}
var pulses: Dictionary = {}
var upgrades: Dictionary = {}
var progression: Dictionary = {}
var pickups: Dictionary = {}


func _ready() -> void:
	enemies = _load("res://data/enemies.json")
	weapons = _load("res://data/weapons.json")
	player = _load("res://data/player.json")
	modes = _load("res://data/modes.json")
	waves = _load("res://data/waves.json")
	pulses = _load("res://data/pulses.json")
	upgrades = _load("res://data/upgrades.json")
	progression = _load("res://data/progression.json")
	pickups = _load("res://data/pickups.json")


func _load(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataDB: cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("DataDB: %s is not a valid JSON object" % path)
		return {}
	return parsed
