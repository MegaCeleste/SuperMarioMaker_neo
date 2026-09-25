class_name HitboxComponent
extends Area2D
## 头部受击 / 足底踩踏 / 侧面碰撞传感器（REQ-REG-005）
## 挂 Layer 7 Sensors（REQ-COL-003）；具体掩码组合由场景配置。

signal stomped(by: Node2D)
signal head_hit(by: Node2D)
signal side_touched(by: Node2D)

func _ready() -> void:
	collision_layer = 1 << 6
	collision_mask = 1 << 1
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	var other := area.get_parent() as Node2D
	if other == null:
		return
	var dy: float = other.global_position.y - get_parent().global_position.y
	if dy < -8.0:
		head_hit.emit(other)
	elif dy > 8.0:
		stomped.emit(other)
	else:
		side_touched.emit(other)
