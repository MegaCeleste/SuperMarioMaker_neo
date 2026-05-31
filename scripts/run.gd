extends State

# 土狼时间持续时间（秒），可在编辑器调整
@export var coyote_time_duration: float = 2
# 土狼时间内重力的百分比（例如：0.50 = 正常重力的50%）
@export var coyote_gravity_percent: float = 0.2

# 记录离开地面的时间（用于土狼时间）
@export_storage var coyote_timer: float = 0.0





func enter() -> void:
	coyote_timer = coyote_time_duration



func physics_update(delta: float) -> void:
	
	coyote_timer -= delta
	
	if not owner.is_on_floor():
		if coyote_timer <= 0:
			state_machine.change_state($"../Air")
			return
		else:
			#var floor_line
				# player.get_floor_normal().rotated(PI/2)
				# Vector2.from_angle(player.get_floor_angle())
			#player.velocity = player.velocity.project(floor_line)
			owner.velocity = owner.velocity.slide(owner.last_floor_normal)
			print(player.last_floor_normal)


	if Input.is_action_just_pressed("player_jump"):
		player.is_priming_jump = (abs(player.velocity.x) >= 160.0)  # 如果水平速度足够快，准备超级跳跃动画
		player.velocity.y = player.SUPER_JUMP_VELOCITY if player.is_priming_jump else player.JUMP_VELOCITY
		player.jump_sound.play()
		state_machine.change_state($"../Air")
		return

	if Input.is_action_pressed("player_duck"):
		state_machine.change_state($"../Duck")
		return

	var dir := Input.get_axis("player_left", "player_right")

	if player.velocity.x == 0 and dir == 0:
		state_machine.change_state($"../Idle")
		return

	if abs(player.velocity.x) >= 160.0 and sign(player.velocity.x) != sign(dir) and dir != 0:
		state_machine.change_state($"../Skid")
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

	
	player.velocity.y += player.GRAVITY * delta * coyote_gravity_percent
