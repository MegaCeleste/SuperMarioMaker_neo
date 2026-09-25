class_name BumpableComponent
extends Node
## 方块被顶起的弹性缓动与上方实体推离（REQ-REG-005、REQ-PHYS-105）

signal bumped(by: Node2D)

const BUMP_HEIGHT := 8.0
const BUMP_DURATION := 0.15

@export var visual_target: Node2D

var _tween: Tween

func bump(by: Node2D = null) -> void:
	if _tween != null and _tween.is_running():
		return
	var target := visual_target if visual_target != null else get_parent() as Node2D
	if target == null:
		return
	var origin := target.position
	_tween = target.create_tween()
	_tween.tween_property(target, "position:y", origin.y - BUMP_HEIGHT, BUMP_DURATION * 0.4)\
		.set_ease(Tween.EASE_OUT)
	_tween.tween_property(target, "position:y", origin.y, BUMP_DURATION * 0.6)\
		.set_ease(Tween.EASE_IN)
	bumped.emit(by)
