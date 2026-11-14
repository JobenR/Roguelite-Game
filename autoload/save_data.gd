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
