class_name ICarryable
extends Node
## 可搬举契约：被抓取、手持、踢出、高抛（REQ-REG-005、REQ-PWR-006~008）
## M0 接口定义；实体继承或组合本类即声明可被玩家搬举。

signal picked_up(by: Node2D)
signal thrown(velocity: Vector2)
signal dropped

var is_carried := false

func pick_up(by: Node2D) -> void:
	is_carried = true
	picked_up.emit(by)

func throw(throw_velocity: Vector2) -> void:
	is_carried = false
	thrown.emit(throw_velocity)

func drop() -> void:
	is_carried = false
	dropped.emit()
