class_name ObjectPool
extends RefCounted
## Reuses scene instances instead of creating and freeing them.

var _scene: PackedScene
var _parent: Node
var _free: Array[Node] = []


func _init(scene: PackedScene, parent: Node, prewarm: int = 0) -> void:
	_scene = scene
	_parent = parent
	for i in prewarm:
		var node := _create()
		node.visible = false
		_free.append(node)


func acquire() -> Node:
	var node: Node = _free.pop_back() if not _free.is_empty() else _create()
	node.visible = true
	return node


func release(node: Node) -> void:
	node.visible = false
	_free.append(node)


func _create() -> Node:
	var node := _scene.instantiate()
	_parent.add_child(node)
	return node
