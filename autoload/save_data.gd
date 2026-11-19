extends Node
## Everything kept between sessions, stored as JSON in the user's data folder:
## the currency (Seals), unlocked inks, permanent boosts, settings and records.

const PATH := "user://blotline_save.json"

var data: Dictionary = {}


func _ready() -> void:
	data = _defaults()
	if FileAccess.file_exists(PATH):
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				# Merge over defaults, so a save from an older version still loads.
				for key: String in parsed:
					if data.has(key) and data[key] is Dictionary and parsed[key] is Dictionary:
						(data[key] as Dictionary).merge(parsed[key], true)
					else:
						data[key] = parsed[key]


func _defaults() -> Dictionary:
	return {
		"seals": 0,
		"ink": "blue",
		"inks": ["blue"],
		"boosts": {},
		"settings": {"sound": true, "music": true, "vibration": true},
		"items": {},
		"gold": 0,
		"char_xp": 0,
		"char_level": 1,
		"skills": {},
		"boosters": {},
		"looks": ["square"],
		"look": "square",
		"vip": false,
		"reclaim": {},
		"vip_claimed": "",
		"use_head_start": true,
		"best_time": 0.0,
		"runs": 0,
		"wins": 0,
	}


func save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveData: could not write %s" % PATH)
		return
	file.store_string(JSON.stringify(data, "  "))


func seals() -> int:
	return int(data.get("seals", 0))


func add_seals(amount: int) -> void:
	data["seals"] = seals() + amount


func setting(key: String) -> bool:
	return bool((data.get("settings", {}) as Dictionary).get(key, true))


func set_setting(key: String, value: bool) -> void:
	(data["settings"] as Dictionary)[key] = value
	save()


func has_ink(id: String) -> bool:
	if bool(DataDB.inks.get(id, {}).get("vip", false)):
		return is_vip()
	return (data.get("inks", []) as Array).has(id)


func ink_cost(id: String) -> int:
	return int(DataDB.meta.get("ink_costs", {}).get(id, 0))


## Buys an ink if it is affordable. Returns true when it is now owned.
func unlock_ink(id: String) -> bool:
	if has_ink(id):
		return true
	if seals() < ink_cost(id):
		return false
	add_seals(-ink_cost(id))
	(data["inks"] as Array).append(id)
	save()
	return true


func item_count(id: String) -> int:
	return int((data.get("items", {}) as Dictionary).get(id, 0))


func add_item(id: String, amount: int = 1) -> void:
	(data["items"] as Dictionary)[id] = item_count(id) + amount
	save()


## Spends one stored item. Returns false when there is none.
func use_item(id: String) -> bool:
	if item_count(id) <= 0:
		return false
	(data["items"] as Dictionary)[id] = item_count(id) - 1
	save()
	return true


func boost_level(id: String) -> int:
	return int((data.get("boosts", {}) as Dictionary).get(id, 0))


## Cost of the next level of a boost, or -1 when it is maxed.
func boost_cost(id: String) -> int:
	var costs: Array = DataDB.meta.get("boosts", {}).get(id, {}).get("costs", [])
	var level := boost_level(id)
	return int(costs[level]) if level < costs.size() else -1


func buy_boost(id: String) -> bool:
	var cost := boost_cost(id)
	if cost < 0 or seals() < cost:
		return false
	add_seals(-cost)
	(data["boosts"] as Dictionary)[id] = boost_level(id) + 1
	save()
	return true


# --- Gold Leaf (the premium currency) ---------------------------------------

func gold() -> int:
	return int(data.get("gold", 0))


func add_gold(amount: int) -> void:
	data["gold"] = gold() + amount


## Pays for something in whichever currency is named. Returns false if short.
func spend(currency: String, amount: int) -> bool:
	if currency == "gold":
		if gold() < amount:
			return false
		add_gold(-amount)
	else:
		if seals() < amount:
			return false
		add_seals(-amount)
	save()
	return true


# --- Character level and skills ----------------------------------------------

func char_level() -> int:
	return int(data.get("char_level", 1))


## Character XP needed to go from `level` to the next.
func char_xp_needed(level: int) -> int:
	var cfg: Dictionary = DataDB.skills.get("xp", {})
	return int(round(float(cfg.get("base", 120.0)) * pow(float(cfg.get("growth", 1.25)), level - 1)))


## Adds character XP. Returns how many levels were gained.
func add_char_xp(amount: int) -> int:
	var gained := 0
	data["char_xp"] = int(data.get("char_xp", 0)) + amount
	while int(data["char_xp"]) >= char_xp_needed(char_level()):
		data["char_xp"] = int(data["char_xp"]) - char_xp_needed(char_level())
		data["char_level"] = char_level() + 1
		gained += 1
	return gained


func skill_rank(branch: String) -> int:
	return int((data.get("skills", {}) as Dictionary).get(branch, 0))


## One point per character level above the first, less what is spent.
func skill_points_free() -> int:
	var spent := 0
	for branch: String in data.get("skills", {}):
		spent += skill_rank(branch)
	return char_level() - 1 - spent


func buy_skill(branch: String) -> bool:
	var nodes: Array = DataDB.skills.get("branches", {}).get(branch, {}).get("nodes", [])
	if skill_points_free() <= 0 or skill_rank(branch) >= nodes.size():
		return false
	(data["skills"] as Dictionary)[branch] = skill_rank(branch) + 1
	save()
	return true


func reset_skills() -> void:
	data["skills"] = {}
	save()


# --- Boosters, looks and VIP ---------------------------------------------------

func booster_runs(id: String) -> int:
	return int((data.get("boosters", {}) as Dictionary).get(id, 0))


func add_booster(id: String, runs: int) -> void:
	(data["boosters"] as Dictionary)[id] = booster_runs(id) + runs
	save()


## Uses up one run of every active booster.
func tick_boosters() -> void:
	for id: String in (data["boosters"] as Dictionary).keys():
		(data["boosters"] as Dictionary)[id] = maxi(0, booster_runs(id) - 1)


func has_look(id: String) -> bool:
	return (data.get("looks", []) as Array).has(id)


func is_vip() -> bool:
	return bool(data.get("vip", false))


## The VIP daily gift. Returns the Gold Leaf granted (0 if none today).
func claim_daily() -> int:
	if not is_vip():
		return 0
	var today := Time.get_date_string_from_system()
	if String(data.get("vip_claimed", "")) == today:
		return 0
	data["vip_claimed"] = today
	var gift := int(DataDB.store.get("vip", {}).get("daily_gold", 20))
	add_gold(gift)
	save()
	return gift
