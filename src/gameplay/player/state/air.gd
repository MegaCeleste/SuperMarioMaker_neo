extends State

func physics_update(delta: float) -> void:
	# 重力已在 Player._physics_process 统一处理

	if Input.is_action_just_released("jump") and player.velocity.y < 0:
		player.velocity.y *= 0.6

	var dir := Input.get_axis("move_left", "move_right")
	var max_speed = player.max_run_speed if Input.is_action_pressed("run") else player.max_walk_speed

	if dir != 0:
		player.velocity.x = move_toward(player.velocity.x, dir * max_speed, player.air_acceleration * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.air_acceleration * 0.1 * delta)

	if dir < 0:
		player.animated_sprite.flip_h = true
	elif dir > 0:
		player.animated_sprite.flip_h = false

	if player.is_on_floor():
		player.is_priming_jump = false
		if Input.is_action_pressed("move_down"):
			state_machine.change_state(state_machine.duck)
		elif dir != 0:
			state_machine.change_state(state_machine.run)
		else:
			if abs(player.velocity.x) > 50:
				state_machine.change_state(state_machine.run)
			else:
				state_machine.change_state(state_machine.idle)
		
		return

	if player.is_priming_jump:
		player.animated_sprite.play("p_jump")
	elif player.velocity.y < 0:
		player.animated_sprite.play("jump")
	else:
		player.animated_sprite.play("fall")
