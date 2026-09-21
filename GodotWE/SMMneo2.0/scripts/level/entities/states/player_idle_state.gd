class_name PlayerIdleState
extends State
## Provides a basic idle behavior to the player.


func _init() -> void:
	intended_class = Player


func physics_process(entity: Node2D, delta: float) -> Variant:
	# type hinting
	var player = entity as Player
	
	# check for void
	if player.global_position.y > player.VOID_LEVEL:
		return PlayerDeathState
	
	# player is not on floor, go to the falling state
	if not player.is_on_floor():
		return PlayerFallingState
	
	# player ducks
	if Input.is_action_pressed("player_duck"):
		return PlayerDuckState
	
	# decelerate
	player.velocity.x = move_toward(player.velocity.x, 0, player.deceleration)
	
	# animations
	if player.kick_anim_timer > 0:
		return
	
	if player.velocity.x == 0:
		player.sprite.speed_scale = 1
		if player._held_item != null and player.sprite.sprite_frames.has_animation("idle_hold"):
			player.sprite.play("idle_hold")
		else:
			player.sprite.play("idle")
	else:
		player.sprite.speed_scale = abs(player.velocity.x) * 12 * delta
		if abs(player.velocity.x) >= player.max_run_speed:
			player.sprite.play("run")
		else:
			if player._held_item != null and player.sprite.sprite_frames.has_animation("walk_hold"):
				player.sprite.play("walk_hold")
			else:
				player.sprite.play("walk")
	
	return


func input(entity: Node2D, event: InputEvent) -> Variant:
	# type hinting
	var player = entity as Player
	
	# player is jumping, go to jumping state
	if event.is_action_pressed("player_jump"):
		return PlayerJumpingState
	
	# player is spin jumping, go to the spin jumping state
	if event.is_action_pressed("player_spin_jump"):
		player.just_fell = true
		return PlayerSpinJumpingState
	
	# moving, go to moving state
	if Input.get_axis("player_left", "player_right") != 0:
		return PlayerMovingState
	
	return
