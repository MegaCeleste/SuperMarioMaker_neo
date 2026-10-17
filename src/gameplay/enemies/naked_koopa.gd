class_name NakedKoopa
extends Enemy
@export_enum("green", "red") var color: String = "green"
enum Phase { EJECTED, RECOVERING, WALKING, JUMPING }
var phase: Phase = Phase.WALKING
var immunity_left: int = 0
var recovery_left: int = 0

func _config_section() -> String:
	return "naked_koopa"

func _visual_group() -> String:
	return "naked_" + color

func eject(direction: float) -> void:
	phase = Phase.EJECTED
	dir = direction
	velocity.x = dir * float(_config["eject_speed"])
	immunity_left = int(_config["immunity_frames"])
	_transition(State.THROWN)

func can_damage_player() -> bool:
	return immunity_left == 0 and not is_dead

func can_be_stomped(_spinning: bool = false) -> bool:
	return immunity_left == 0 and not is_dead

func _process_state(delta: float) -> void:
	if is_dead:
		return
	immunity_left = maxi(0, immunity_left - 1)
	if phase == Phase.EJECTED and is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, float(_config["slide_decel"]) * delta)
		if absf(velocity.x) < 1.5:
			phase = Phase.RECOVERING
			recovery_left = int(_config["recovery_frames"])
			_transition(State.STUNNED)
	elif phase == Phase.RECOVERING:
		recovery_left = maxi(0, recovery_left - 1)
		if recovery_left == 0:
			phase = Phase.WALKING
			_transition(State.WALKING)
			velocity.y = float(_config["recover_jump"])
	elif phase in [Phase.WALKING, Phase.JUMPING]:
		for node: Node in get_tree().get_nodes_in_group("entity_shells"):
			var shell: KoopaShell = node as KoopaShell
			if not is_instance_valid(shell) or shell.is_dead or shell.is_queued_for_deletion() or shell.get_world_2d() != get_world_2d():
				continue
			if shell.shell_kind != color or not shell.is_empty_stationary():
				continue
			var offset: Vector2 = shell.feet_position() - feet_position()
			if phase == Phase.WALKING and offset.x * dir > 0.0 and absf(offset.x) <= 16.0 and absf(offset.y) <= 4.0:
				phase = Phase.JUMPING
				velocity.y = float(_config["enter_jump"])
			if phase == Phase.JUMPING and absf(offset.x) <= 8.0 and velocity.y >= 0.0 and offset.y >= -1.0 and offset.y <= 14.0:
				if shell.enter_koopa(color):
					retire()
					return
		if phase == Phase.JUMPING and is_on_floor() and velocity.y >= 0.0:
			phase = Phase.WALKING
	if color == "red" and phase == Phase.WALKING and is_on_floor() and not has_floor_ahead():
		dir *= -1.0

func _render(delta: float) -> void:
	super._render(delta)
	if not is_dead and phase in [Phase.EJECTED, Phase.RECOVERING] and sprite.sprite_frames.has_animation(&"ejected"):
		sprite.animation = &"ejected"
		sprite.frame = 0
