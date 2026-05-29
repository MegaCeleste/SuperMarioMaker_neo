extends State

func enter() -> void:
	player.animated_sprite.play("idle")

func physics_update(delta: float) -> void:

	player.velocity.x = move_toward(player.velocity.x, 0, player.ground_acceleration * delta)
	if not player.is_on_floor():
		player.state_machine.change_state($"../Air")
		return

	if Input.is_action_just_pressed("player_jump"):
		player.velocity.y = player.JUMP_VELOCITY
		player.jump_sound.play()
		player.state_machine.change_state($"../Air")
		return

	if Input.is_action_pressed("player_duck"):
		player.state_machine.change_state($"../Duck")
		return

	var direction = Input.get_axis("player_left", "player_right")
	if direction != 0:
		player.state_machine.change_state($"../Run")
		return

	player.velocity.y += player.GRAVITY * delta

	