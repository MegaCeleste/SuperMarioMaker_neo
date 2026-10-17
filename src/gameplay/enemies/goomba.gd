class_name Goomba
extends Enemy
## REQ-PHYS-121.

func _config_section() -> String:
	return "goomba"


func stomp(spinning: bool) -> void:
	if is_dead:
		return
	if spinning:
		spin_defeat()
		return
	_transition(State.SQUASHED)
	_disable_interactions()
	velocity = Vector2.ZERO
	defeated.emit(self)
	_render(0.0)
