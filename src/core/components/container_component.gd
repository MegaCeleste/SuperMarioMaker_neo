class_name ContainerComponent
extends Node
## REQ-REG-005. Content is addressed through Registry.

signal item_released(object_id: String, spawn_position: Vector2)

@export var contained_item: String = "smm.item.coin"
var pop_height: float = 0.0
var pop_duration: float = 0.0
var _used: bool = false


func release_item() -> void:
	if _used:
		return
	_used = true
	var owner: Node2D = get_parent() as Node2D
	item_released.emit(contained_item, owner.global_position + Vector2(0.0, -pop_height))


func is_used() -> bool:
	return _used
