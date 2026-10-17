class_name BumpableComponent
extends Node
## REQ-REG-005, REQ-PHYS-105/122.

signal bumped(by: Node2D)
signal finished

@export var visual_target: Node2D
var _height: float = 0.0
var _duration: float = 0.0
var _tween: Tween


func configure(height: float, duration: float) -> void:
	_height = height
	_duration = duration


func is_running() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


func bump(by: Node2D = null) -> void:
	if is_running() or visual_target == null:
		return
	var origin: Vector2 = visual_target.position
	_tween = visual_target.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(visual_target, "position:y", origin.y - _height, _duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(visual_target, "position:y", origin.y, _duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_on_finished)
	bumped.emit(by)


func _on_finished() -> void:
	finished.emit()
