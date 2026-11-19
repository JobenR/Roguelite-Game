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
var pictures: Dictionary = {}
var levels: Dictionary = {}
var mode_text: Dictionary = {}
# Untouched copies, so each mode's wording is applied to fresh data.
var _plain_upgrades: Dictionary = {}
var _plain_pickups: Dictionary = {}
var _terms: Dictionary = {}


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
	pictures = _load("res://data/pictures.json")
	levels = _load("res://data/levels.json")
	mode_text = _load("res://data/mode_text.json")


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


## Rewords cards, pickups and a few UI terms for a mode (data/mode_text.json).
## Modes without an entry get the original wording back. Called as a mode
## starts and when the title screen opens.
func apply_mode_text(mode_id: String) -> void:
	if _plain_upgrades.is_empty():
		_plain_upgrades = upgrades.duplicate(true)
		_plain_pickups = pickups.duplicate(true)
	upgrades = _plain_upgrades.duplicate(true)
	pickups = _plain_pickups.duplicate(true)
	var text: Dictionary = mode_text.get(mode_id, {})
	var cards: Dictionary = upgrades.get("upgrades", {})
	var worded: Dictionary = text.get("upgrades", {})
	for id: String in worded:
		if cards.has(id):
			cards[id]["name"] = worded[id].get("name", cards[id].get("name", id))
			cards[id]["short"] = worded[id].get("short", cards[id].get("short", ""))
	var types: Dictionary = pickups.get("types", {})
	var names: Dictionary = text.get("pickups", {})
	for id: String in names:
		if types.has(id):
			types[id]["name"] = names[id]
	var sets: Dictionary = upgrades.get("sets", {})
	var set_names: Dictionary = text.get("sets", {})
	for id: String in set_names:
		if sets.has(id):
			sets[id]["name"] = set_names[id]
	_terms = text.get("terms", {})


## A UI word as the current mode says it ("Deluge" is "Purge" in Reclaim).
func term(word: String) -> String:
	return String(_terms.get(word, word))


## A number from data/arsenal.json: arsenal_num("mines", "damage", 30.0).
func arsenal_num(id: String, key: String, fallback: float) -> float:
	return float(arsenal.get(id, {}).get(key, fallback))
