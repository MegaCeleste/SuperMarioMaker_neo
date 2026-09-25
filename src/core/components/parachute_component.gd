class_name ParachuteComponent
extends Node
## 降落伞低速降落、触地自动脱落（REQ-REG-005）
## M0 占位：仅声明接口，行为实现属后续里程碑。由属性 has_parachute 触发挂载（REQ-REG-003）。

@export var fall_speed := 30.0

signal detached

func detach() -> void:
	detached.emit()
	queue_free()
