# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerFallingState
extends PlayerState
## Provides a basic falling behavior to the player.

var _coyote_timer := -1.0
var _buffer_timer := -1.0
var _buffer_spin := false


func start() -> Script:
	super()
	# enable coyote time
	_coyote_timer = 0.0 if player.just_fell else -1.0
	player.just_fell = false
	_buffer_timer = -1
	return null


func physics_process(delta: float) -> Script:
	super(delta)
	
	var direction = Input.get_axis("player_left", "player_right")
	
	if _coyote_timer != -1:
		_coyote_timer += delta
	if _buffer_timer >= 0:
		_buffer_timer += delta
	if Input.is_action_just_pressed("player_jump") \
			or (Input.is_action_just_pressed("player_spin_jump") and not player.is_ducking()):
		_buffer_timer = 0
		_buffer_spin = Input.is_action_just_pressed("player_spin_jump")
	
	if _coyote_timer >= 0 and _coyote_timer <= player.coyote_time and _buffer_timer == 0:
		_coyote_timer = -1
		return PlayerSpinJumpingState if _buffer_spin else PlayerJumpingState
	
	position_held_item(direction)
	
	# accelerate
	apply_horizontal_motion(direction, delta)
	
	
	if player.is_on_floor():
		if _buffer_timer >= 0 and _buffer_timer <= player.jump_buffer_time:
			return PlayerSpinJumpingState if _buffer_spin else PlayerJumpingState
		if direction == 0:
			return PlayerIdleState
		else:
			return PlayerMovingState
	
	# animations
	if player.can_change_sprite():
		if _coyote_timer == -1 or (_coyote_timer > player.coyote_time):
			if player.velocity.y < 0:
				player.sprite.play("jump")
			else:
				player.sprite.play("fall")
			if direction < 0:
				player.sprite.flip_h = true
			elif direction > 0:
				player.sprite.flip_h = false
	return null


func input(event: InputEvent) -> Script:
	super(event)
	
	if player.is_on_floor():
		return move_check(event)
	
	return null
