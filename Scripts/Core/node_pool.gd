class_name NodePool
extends RefCounted
## Pool di nodi riutilizzabili: niente instantiate/queue_free durante la partita.
## I nodi restano nel tree, nascosti quando liberi.

var _free: Array[Node3D] = []
var _factory: Callable
var _parent: Node


func _init(parent: Node, factory: Callable, prewarm: int) -> void:
	_parent = parent
	_factory = factory
	for i in prewarm:
		_free.append(_create())


func acquire() -> Node3D:
	var item: Node3D = _free.pop_back() if not _free.is_empty() else _create()
	item.visible = true
	return item


func release(item: Node3D) -> void:
	item.visible = false
	_free.append(item)


func _create() -> Node3D:
	var item: Node3D = _factory.call()
	item.visible = false
	_parent.add_child(item)
	return item
