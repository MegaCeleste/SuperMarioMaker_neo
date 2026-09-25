class_name WingedComponent
extends Node
## 翅膀振翅悬浮与跳跃动力学（REQ-REG-005）
## M0 占位：仅声明接口，行为实现属后续里程碑。由属性 is_winged 触发挂载（REQ-REG-003）。

@export var hover_amplitude := 4.0
@export var hover_frequency := 2.0

func is_winged() -> bool:
	return true
