extends Node
## GizmoEventBus — 集中式机关事件总线（REQ-ARC-012；信号契约见 backlog-draft §10）

signal on_off_state_changed(is_on: bool)
signal p_switch_activated(duration: float)
signal p_switch_expired
signal pow_triggered(epicenter: Vector2)
signal key_collected(key_id: String)

func set_on_off(is_on: bool) -> void:
	on_off_state_changed.emit(is_on)

func activate_p_switch(duration: float) -> void:
	p_switch_activated.emit(duration)

func expire_p_switch() -> void:
	p_switch_expired.emit()

func trigger_pow(epicenter: Vector2) -> void:
	pow_triggered.emit(epicenter)

func collect_key(key_id: String) -> void:
	key_collected.emit(key_id)
