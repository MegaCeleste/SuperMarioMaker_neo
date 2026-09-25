extends State

func enter() -> void:
	player.animated_sprite.play("spin_jump")
	player.animated_sprite.speed_scale = 1.0
	player.velocity.y = player.SPIN_JUMP_VELOCITY
	player.spin_jump_sound.play()

func physics_update(delta: float) -> void:
	# 松开跳跃键时提前结束上升（类似普通跳跃的短跳机制）
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

	# 落地时退出
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

	# TODO: 踩到带刺敌人时不会受伤，而是弹起并保持旋转跳状态
	# func _on_enemy_bounce() -> void:
	#     player.velocity.y = player.JUMP_VELOCITY * 0.8
	#     # 状态不变，保持 spin_jump
