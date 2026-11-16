extends Node
## Run-scoped upgrade state. Every stat is (base + add) * (1 + mult), where the
## add and mult totals come from upgrade, synergy and set-bonus effects in
## upgrades.json. Systems ask for values on demand, so a new upgrade needs no
## code if it reuses an existing stat.

var levels: Dictionary = {}      # upgrade id -> level
var synergies: Dictionary = {}   # synergy id -> true
var set_tiers: Dictionary = {}   # set id -> number of tiers unlocked
var banished: Dictionary = {}    # upgrade id -> true (never offered again this run)

var _add: Dictionary = {}
var _mult: Dictionary = {}


func _ready() -> void:
	Events.run_started.connect(reset)


func reset() -> void:
	levels.clear()
	synergies.clear()
	set_tiers.clear()
	banished.clear()
	_add.clear()
	_mult.clear()
	# The chosen ink's strengths and weaknesses apply for the whole run.
	_apply_effects(DataDB.inks.get(GameState.ink_id, {}).get("effects", []))
	# Permanent boosts bought with Seals.
	var boosts: Dictionary = DataDB.meta.get("boosts", {})
	for id: String in boosts:
		var owned := SaveData.boost_level(id)
		if owned > 0:
			_apply_effects([boosts[id]], float(owned))
	# The skill tree: every node bought in each branch.
	var branches: Dictionary = DataDB.skills.get("branches", {})
	for branch: String in branches:
		var nodes: Array = branches[branch].get("nodes", [])
		for i in mini(SaveData.skill_rank(branch), nodes.size()):
			_apply_effects(nodes[i].get("effects", []))
	if SaveData.is_vip():
		_add["reroll"] = float(_add.get("reroll", 0.0)) + float(DataDB.store.get("vip", {}).get("reroll", 1))
	Events.upgrade_applied.emit("")


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


func defs() -> Dictionary:
	return DataDB.upgrades.get("upgrades", {})


## Up to `count` distinct upgrade ids that are not maxed or banished. Rarer
## cards are less likely; cards you already own are more likely, so builds
## deepen instead of spreading thin.
func roll_choices(count: int) -> Array[String]:
	var weights: Dictionary = DataDB.upgrades.get("rarity_weights", {})
	var owned_mult := float(DataDB.upgrades.get("owned_weight_mult", 1.0))
	var pool: Array[String] = []
	var pool_weights: Array[float] = []
	var all := defs()
	for id: String in all:
		if banished.has(id) or bool(all[id].get("retired", false)) or level_of(id) >= int(all[id].get("max_level", 1)):
			continue
		var weight := float(weights.get(String(all[id].get("rarity", "common")), 100.0))
		if level_of(id) > 0:
			weight *= owned_mult
		pool.append(id)
		pool_weights.append(weight)
	var picked: Array[String] = []
	while picked.size() < count and not pool.is_empty():
		var total := 0.0
		for w in pool_weights:
			total += w
		var roll := randf() * total
		var index := 0
		for i in pool.size():
			roll -= pool_weights[i]
			if roll <= 0.0:
				index = i
				break
		picked.append(pool[index])
		pool.remove_at(index)
		pool_weights.remove_at(index)
	return picked


func banish(id: String) -> void:
	banished[id] = true


func apply(id: String) -> void:
	var all := defs()
	if not all.has(id):
		push_error("Upgrades: unknown upgrade '%s'" % id)
		return
	levels[id] = level_of(id) + 1
	# Some upgrades count double at level 1, so a first pick is felt at once.
	var first_double := level_of(id) == 1 and bool(all[id].get("first_level_double", false))
	_apply_effects(all[id].get("effects", []), 2.0 if first_double else 1.0)
	Events.upgrade_applied.emit(id)
	_check_synergies()
	_check_sets()


## Names of synergies that taking this upgrade would complete right now.
func synergy_hint(id: String) -> String:
	if level_of(id) > 0:
		return ""
	var names: Array[String] = []
	var all: Dictionary = DataDB.upgrades.get("synergies", {})
	for sid: String in all:
		if synergies.has(sid):
			continue
		var requires: Array = all[sid].get("requires", [])
		if not requires.has(id):
			continue
		var others_owned := true
		for req: String in requires:
			if req != id and level_of(req) == 0:
				others_owned = false
		if others_owned:
			names.append(String(all[sid].get("name", sid)))
	return ", ".join(names)


## For a card you do not own yet: the partner card that would make a synergy,
## so the player can plan toward it. Empty when there is none.
func partner_hint(id: String) -> String:
	if level_of(id) > 0:
		return ""
	var all: Dictionary = DataDB.upgrades.get("synergies", {})
	for sid: String in all:
		var requires: Array = all[sid].get("requires", [])
		if synergies.has(sid) or not requires.has(id):
			continue
		for req: String in requires:
			if req != id and level_of(req) == 0:
				return "%s (with %s)" % [String(all[sid].get("name", sid)), String(defs().get(req, {}).get("name", req))]
	return ""


## Number of different owned cards in a set.
func set_count(set_id: String) -> int:
	var total := 0
	var all := defs()
	for id: String in levels:
		if String(all.get(id, {}).get("set", "")) == set_id:
			total += 1
	return total


## Progress text toward the next tier of this card's set, counting the card
## itself if it would be new. Empty when the set is complete.
func set_hint(id: String) -> String:
	var set_id := String(defs().get(id, {}).get("set", ""))
	var set_def: Dictionary = DataDB.upgrades.get("sets", {}).get(set_id, {})
	if set_def.is_empty():
		return ""
	var have := set_count(set_id) + (1 if level_of(id) == 0 else 0)
	for tier: Dictionary in set_def.get("tiers", []):
		var need := int(tier.get("count", 0))
		if set_count(set_id) < need:
			return "%s set %d/%d: %s" % [String(set_def.get("name", set_id)), mini(have, need), need, String(tier.get("desc", ""))]
	return ""


func _check_synergies() -> void:
	var all: Dictionary = DataDB.upgrades.get("synergies", {})
	for sid: String in all:
		if synergies.has(sid):
			continue
		var complete := true
		for req: String in all[sid].get("requires", []):
			if level_of(req) == 0:
				complete = false
		if complete:
			synergies[sid] = true
			_apply_effects(all[sid].get("effects", []))
			Events.synergy_unlocked.emit(String(all[sid].get("name", sid)), String(all[sid].get("desc", "")))


func _check_sets() -> void:
	var sets: Dictionary = DataDB.upgrades.get("sets", {})
	for set_id: String in sets:
		var tiers: Array = sets[set_id].get("tiers", [])
		var unlocked := int(set_tiers.get(set_id, 0))
		while unlocked < tiers.size() and set_count(set_id) >= int(tiers[unlocked].get("count", 99)):
			_apply_effects(tiers[unlocked].get("effects", []))
			Events.set_bonus.emit(String(sets[set_id].get("name", set_id)), int(tiers[unlocked].get("count", 0)), String(tiers[unlocked].get("desc", "")))
			unlocked += 1
		set_tiers[set_id] = unlocked


func _apply_effects(effects: Array, scale: float = 1.0) -> void:
	for effect: Dictionary in effects:
		var stat := String(effect.get("stat", ""))
		if effect.has("add"):
			_add[stat] = float(_add.get(stat, 0.0)) + float(effect["add"]) * scale
		if effect.has("mult"):
			_mult[stat] = float(_mult.get(stat, 0.0)) + float(effect["mult"]) * scale
