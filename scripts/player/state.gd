class_name State
extends Node

var player: Player
var state_machine: StateMachine

func enter() -> void:
    pass

func exit() -> void:
    pass

func update(_delta: float) -> void:
    pass

func physics_update(_delta: float) -> void:
    pass

# 是否允许 Player 统一应用重力（Dead 在悬空阶段返回 false）
func can_apply_gravity() -> bool:
    return true
