class_name PlayerIdleState
extends PlayerState
## Provides a basic idle behavior to the player.


func start() -> Script:
	super()
	# Moving.end resets non-ground animation speed; keep coasting continuous
	# on the transition tick before Idle's first physics_process.
	if player.is_on_floor() and not is_zero_approx(player.velocity.x) \
			and player.sprite.animation in [&"walk", &"run", &"hold_walk"]:
		player.play_ground_animation(player.sprite.animation)
	return null


func physics_process(delta: float) -> Script:
	super(delta)
	
	# player is not on floor, go to the falling state
	if not player.is_on_floor():
		player.just_fell = true
		return PlayerFallingState
	var jump := ground_jump_check()
	if jump != null:
		return jump
	if player.slope_slide_check():
		return PlayerSlopeSlideState
	if Input.get_axis("player_left", "player_right") != 0:
		return PlayerMovingState
	
	# decelerate
	apply_horizontal_motion(0, delta)
	
	# animations
	if player.can_change_sprite():
		if player.velocity.x == 0:
			player.sprite.speed_scale = 1
			if Input.is_action_pressed("player_up"):
				if player.held_item == null:
					player.sprite.play("look_up")
				else:
					player.sprite.play("hold_look_up")
			else:
				if player.held_item == null:
					player.sprite.play("idle")
				else:
					player.sprite.play("hold_idle")
		else:
			if player.held_item == null:
				if player.p_meter > 5:
					player.play_ground_animation(&"run")
				else:
					player.play_ground_animation(&"walk")
			else:
				player.play_ground_animation(&"hold_walk")
	
	return null


func input(event: InputEvent) -> Script:
	super(event)
	return move_check(event)
