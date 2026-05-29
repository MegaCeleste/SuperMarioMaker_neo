class_name StateMachine
extends Node

@export var initial_state: State
var current_state: State

# 初始化状态机，把玩家的引用分发给下面的所有状态节点
func init(player: Player) -> void:
	for child in get_children():
		if child is State:
			child.player = player
			child.state_machine = self

	# 启动初始状态
	if initial_state:
		change_state(initial_state)

# 切换状态
func change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	if current_state:
		current_state.exit()

	current_state = new_state
	current_state.enter()

# 接收Player传来的物理帧更新
func process_physics(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)
