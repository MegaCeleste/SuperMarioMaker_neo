extends State

func enter() -> void:
	player.animated_sprite.play("duck")
	player.standing_shape.disabled = true
	player.duck_shape.disabled = false

func exit() -> void:
	player.standing_shape.disabled = false
	player.duck_shape.disabled = true

func physics_update(delta: float) -> void:
	var dir := Input.get_axis("player_left", "player_right")
	
	if dir < 0:
		player.animated_sprite.flip_h = true
	elif dir > 0:
		player.animated_sprite.flip_h = false

	if not player.is_on_floor():
		player.velocity.y += player.GRAVITY * delta
		player.velocity.y = min(player.velocity.y, player.max_fall_speed)

		if Input.is_action_just_released("player_jump") and player.velocity.y < 0:
			player.velocity.y *= 0.6

		var max_speed = player.max_run_speed if Input.is_action_pressed("player_run") else player.max_walk_speed
		
		if dir != 0:
			player.velocity.x = move_toward(player.velocity.x, dir * max_speed, player.air_acceleration * delta)
		else:
			player.velocity.x = move_toward(player.velocity.x, 0, player.air_acceleration * 0.1 * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.ground_acceleration * delta)

		if Input.is_action_just_pressed("player_jump"):
			player.velocity.y = player.SUPER_JUMP_VELOCITY if player.is_priming_jump else player.JUMP_VELOCITY
			player.jump_sound.play()

	if not Input.is_action_pressed("player_duck") and player.is_on_floor():
		if abs(player.velocity.x) > 10:
			state_machine.change_state($"../Run")
		else:
			state_machine.change_state($"../Idle")
