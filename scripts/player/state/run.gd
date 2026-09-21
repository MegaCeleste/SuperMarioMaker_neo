extends State

func enter() -> void:
	pass

func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		state_machine.change_state(state_machine.air)
		return

	# 单独按↓方向键 → 旋转跳
	if Input.is_action_just_pressed("player_spin_jump"):
		state_machine.change_state(state_machine.spin_jump)
		return

	if Input.is_action_just_pressed("player_jump"):
		player.is_priming_jump = (abs(player.velocity.x) >= 160.0)
		player.velocity.y = player.SUPER_JUMP_VELOCITY if player.is_priming_jump else player.JUMP_VELOCITY
		player.jump_sound.play()
		state_machine.change_state(state_machine.air)
		return

	if Input.is_action_pressed("player_duck"):
		state_machine.change_state(state_machine.duck)
		return

	var dir := Input.get_axis("player_left", "player_right")

	if player.velocity.x == 0 and dir == 0:
		state_machine.change_state(state_machine.idle)
		return

	if abs(player.velocity.x) >= 160.0 and sign(player.velocity.x) != sign(dir) and dir != 0:
		state_machine.change_state(state_machine.skid)
		return

	var max_speed = player.max_run_speed if Input.is_action_pressed("player_run") else player.max_walk_speed
	player.velocity.x = move_toward(player.velocity.x, dir * max_speed, player.ground_acceleration * delta)

	if dir < 0:
		player.animated_sprite.flip_h = true
	elif dir > 0:
		player.animated_sprite.flip_h = false

	if abs(player.velocity.x) >= 180:
		player.animated_sprite.play("run")
		player.animated_sprite.speed_scale = lerp(0.6, 3.0, abs(player.velocity.x) / player.max_run_speed)
	else:
		player.animated_sprite.play("walk")
		player.animated_sprite.speed_scale = lerp(0.6, 2.0, abs(player.velocity.x) / player.max_walk_speed)
