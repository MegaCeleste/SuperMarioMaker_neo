extends State

func physics_update(delta: float) -> void:
	player.velocity.y += player.GRAVITY * delta
	player.velocity.y = min(player.velocity.y, player.max_fall_speed)

	if Input.is_action_just_released("player_jump") and player.velocity.y < 0:
		player.velocity.y *= 0.6

	var dir := Input.get_axis("player_left", "player_right")
	var max_speed = player.max_run_speed if Input.is_action_pressed("player_run") else player.max_walk_speed

	if dir != 0:
		player.velocity.x = move_toward(player.velocity.x, dir * max_speed, player.air_acceleration * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.air_acceleration * 0.1 * delta) # 在空中时，玩家的水平速度会逐渐减慢，模拟空气阻力

	if dir < 0:
		player.animated_sprite.flip_h = true
	elif dir > 0:
		player.animated_sprite.flip_h = false

	# 
	if player.is_on_floor():
		player.is_priming_jump = false
		if Input.is_action_pressed("player_duck"):
			state_machine.change_state($"../Duck")
		elif dir != 0:
			state_machine.change_state($"../Run")
		else:
			if abs(player.velocity.x) > 50:
				state_machine.change_state($"../Run")
			else:
				state_machine.change_state($"../Idle")
		
		return # 阻止代码继续运行

	if player.is_priming_jump:
		player.animated_sprite.play("p_jump")
	elif player.velocity.y < 0:
		player.animated_sprite.play("jump")
	else:
		player.animated_sprite.play("fall")
