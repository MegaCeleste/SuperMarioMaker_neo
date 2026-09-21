class_name PlayerDuckState
extends State
## Provides ducking behavior to the player.

func _init() -> void:
	intended_class = Player

func start(entity: Node2D) -> Variant:
	var player = entity as Player
	if player._held_item != null and player.sprite.sprite_frames.has_animation("duck_hold"):
		player.sprite.play("duck_hold")
	else:
		player.sprite.play("duck")
	player.duck_shape.disabled = false
	return

func end(entity: Node2D) -> void:
	var player = entity as Player
	player.duck_shape.disabled = true

func physics_process(entity: Node2D, delta: float) -> Variant:
	var player = entity as Player
	
	if player.global_position.y > player.VOID_LEVEL:
		return PlayerDeathState
	
	var direction := Input.get_axis("player_left", "player_right")
	
	if direction != 0:
		player.sprite.flip_h = direction < 0
		player.direction = direction
	
	# Restore duck animation after kick ends
	if player.kick_anim_timer <= 0 and player.sprite.animation != "duck" and player.sprite.animation != "duck_hold":
		if player._held_item != null and player.sprite.sprite_frames.has_animation("duck_hold"):
			player.sprite.play("duck_hold")
		else:
			player.sprite.play("duck")
	
	if not player.is_on_floor():
		# 空中下蹲：保持水平控制，短跳机制
		if Input.is_action_just_released("player_jump") and player.velocity.y < 0:
			player.velocity.y *= 0.6
		
		var max_speed = (
			player.max_run_speed
			if Input.is_action_pressed("player_run")
			else player.max_walk_speed
		)
		
		if direction != 0:
			player.velocity.x = move_toward(
				player.velocity.x,
				max_speed * direction,
				player.acceleration
			)
		else:
			player.velocity.x = move_toward(
				player.velocity.x, 0, player.deceleration * 0.5
			)
	else:
		# 地面下蹲：减速
		player.velocity.x = move_toward(player.velocity.x, 0, player.deceleration)
		
		if Input.is_action_just_pressed("player_jump"):
			if abs(player.velocity.x) >= player.max_run_speed:
				player.velocity.y = -player.fast_jump_speed
			elif abs(player.velocity.x) >= player.max_walk_speed:
				player.velocity.y = -player.slow_jump_speed
			else:
				player.velocity.y = -player.idle_jump_speed
			return PlayerJumpingState
	
	# 松开下蹲键 → 回到 run 或 idle
	if not Input.is_action_pressed("player_duck") and player.is_on_floor():
		if abs(player.velocity.x) > 10:
			return PlayerMovingState
		else:
			return PlayerIdleState
	
	return
