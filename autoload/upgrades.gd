extends Node
## Run-scoped upgrade state. Every stat is (base + add) * (1 + mult), where the
## add and mult totals come from upgrade and synergy effects in upgrades.json.
## Systems ask for values on demand, so new upgrades need no code if they
## reuse an existing stat.

var levels: Dictionary = {}     # upgrade id -> level
var synergies: Dictionary = {}  # synergy id -> true

var _add: Dictionary = {}
var _mult: Dictionary = {}


func _ready() -> void:
	Events.run_started.connect(reset)


func reset() -> void:
	levels.clear()
	synergies.clear()
	_add.clear()
	_mult.clear()


## Final value of a stat given its base.
func value(stat: String, base: float) -> float:
	return (base + float(_add.get(stat, 0.0))) * (1.0 + float(_mult.get(stat, 0.0)))


## Flat bonus of a stat whose base is zero (pierce, ricochet, ink_burn...).
func bonus(stat: String) -> float:
	return value(stat, 0.0)


func mult_of(stat: String) -> float:
	return 1.0 + float(_mult.get(stat, 0.0))


func level_of(id: String) -> int:
	return int(levels.get(id, 0))


## Up to `count` distinct upgrade ids that are not yet maxed.
func roll_choices(count: int) -> Array[String]:
	var pool: Array[String] = []
	var defs: Dictionary = DataDB.upgrades.get("upgrades", {})
	for id: String in defs:
		if level_of(id) < int(defs[id].get("max_level", 1)):
			pool.append(id)
	pool.shuffle()
	if pool.size() > count:
		pool.resize(count)
	return pool


func apply(id: String) -> void:
	var defs: Dictionary = DataDB.upgrades.get("upgrades", {})
	if not defs.has(id):
		push_error("Upgrades: unknown upgrade '%s'" % id)
		return
	levels[id] = level_of(id) + 1
	# Some upgrades count double at level 1, so a first pick is felt at once.
	var first_double := level_of(id) == 1 and bool(defs[id].get("first_level_double", false))
	_apply_effects(defs[id].get("effects", []), 2.0 if first_double else 1.0)
	Events.upgrade_applied.emit(id)
	_check_synergies()


## Names of synergies that taking this upgrade would complete right now.
func synergy_hint(id: String) -> String:
	if level_of(id) > 0:
		return ""
	var names: Array[String] = []
	var defs: Dictionary = DataDB.upgrades.get("synergies", {})
	for sid: String in defs:
		if synergies.has(sid):
			continue
		var requires: Array = defs[sid].get("requires", [])
		if not requires.has(id):
			continue
		var others_owned := true
		for req: String in requires:
			if req != id and level_of(req) == 0:
				others_owned = false
		if others_owned:
			names.append(String(defs[sid].get("name", sid)))
	return ", ".join(names)


func _check_synergies() -> void:
	var defs: Dictionary = DataDB.upgrades.get("synergies", {})
	for sid: String in defs:
		if synergies.has(sid):
			continue
		var complete := true
		for req: String in defs[sid].get("requires", []):
			if level_of(req) == 0:
				complete = false
		if complete:
			synergies[sid] = true
			_apply_effects(defs[sid].get("effects", []))
			Events.synergy_unlocked.emit(String(defs[sid].get("name", sid)), String(defs[sid].get("desc", "")))


func _apply_effects(effects: Array, scale: float = 1.0) -> void:
	for effect: Dictionary in effects:
		var stat := String(effect.get("stat", ""))
		if effect.has("add"):
			_add[stat] = float(_add.get(stat, 0.0)) + float(effect["add"]) * scale
		if effect.has("mult"):
			_mult[stat] = float(_mult.get(stat, 0.0)) + float(effect["mult"]) * scale
