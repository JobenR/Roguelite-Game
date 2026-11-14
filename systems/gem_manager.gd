class_name GemManager
extends Node2D
## Owns XP gems: pooled drops on kill, magnet pull inside the pickup radius,
## collection on contact. When the gem cap is reached, new XP is folded into
## an existing gem so nothing is lost.

const GEM_SCENE := preload("res://entities/gems/gem.tscn")

var active: Array[Gem] = []

var _pool: ObjectPool
var _player: Player
var _max_gems: int = 400
var _magnet_speed: float = 520.0


func setup(player: Player) -> void:
	_player = player
	_pool = ObjectPool.new(GEM_SCENE, self, 64)
	_max_gems = int(DataDB.progression.get("max_gems", 400))
	_magnet_speed = float(DataDB.progression.get("gem_magnet_speed", 520.0))
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.power_granted.connect(_on_power_granted)


func _on_enemy_killed(_type_id: String, pos: Vector2, _splat_radius: float, xp: int, _dir: Vector2) -> void:
	if xp <= 0:
		return
	if active.size() >= _max_gems:
		active[randi() % active.size()].xp += xp
		return
	var gem: Gem = _pool.acquire()
	gem.drop(pos, xp)
	active.append(gem)


## The Magnet pickup pulls in every gem on the page.
func _on_power_granted(id: String, _seconds: float) -> void:
	if id == "magnet":
		for gem in active:
			gem.magnet = true


func _process(delta: float) -> void:
	if _player == null or not GameState.is_playing():
		return
	var player_pos := _player.position
	var pickup := _player.pickup_radius()
	var pickup_sq := pickup * pickup
	var collect := _player.radius + 8.0
	var collect_sq := collect * collect
	var step := _magnet_speed * delta
	var i := active.size() - 1
	while i >= 0:
		var gem := active[i]
		var d_sq := gem.position.distance_squared_to(player_pos)
		if d_sq <= collect_sq:
			active[i] = active[active.size() - 1]
			active.pop_back()
			_pool.release(gem)
			GameState.add_xp(gem.xp)
		elif gem.magnet or d_sq <= pickup_sq:
			gem.magnet = true
			gem.position = gem.position.move_toward(player_pos, step)
		i -= 1
