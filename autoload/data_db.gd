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
var milestones: Dictionary = {}
var arsenal: Dictionary = {}
var inks: Dictionary = {}
var meta: Dictionary = {}
var skills: Dictionary = {}
var store: Dictionary = {}


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
	milestones = _load("res://data/milestones.json")
	arsenal = _load("res://data/arsenal.json")
	inks = _load("res://data/inks.json")
	meta = _load("res://data/meta.json")
	skills = _load("res://data/skills.json")
	store = _load("res://data/store.json")


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


## A number from data/arsenal.json: arsenal_num("mines", "damage", 30.0).
func arsenal_num(id: String, key: String, fallback: float) -> float:
	return float(arsenal.get(id, {}).get(key, fallback))
