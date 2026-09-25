class_name ContainerComponent
extends Node
## 方块内藏物品的弹出与激活（REQ-REG-005）
## 内藏物 ID 来自关卡数据 properties.contained_item（REQ-REG-003）。

signal item_released(object_id: String, spawn_position: Vector2)

@export var contained_item: String = "smm.item.coin"
## 弹出缓动高度（px）
@export var pop_height := 16.0
## 弹出时长（秒）
@export var pop_duration := 0.4

var _used := false

func release_item() -> void:
	if _used:
		return
	_used = true
	var parent_2d := get_parent() as Node2D
	var spawn_pos := Vector2.ZERO
	if parent_2d != null:
		spawn_pos = parent_2d.global_position + Vector2(0, -pop_height)
	item_released.emit(contained_item, spawn_pos)

func is_used() -> bool:
	return _used
