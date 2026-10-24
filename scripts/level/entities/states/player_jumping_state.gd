# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerJumpingState
extends PlayerState
## Provides jumping behavior to the player.

# The type of jump that should be buffered
enum _JumpBufferType {
	NONE,
	JUMP,
	SPIN_JUMP
}

var _long_jump := false
var _grav_comp: GravityComponent
var _jump_buffer: _JumpBufferType
var _jump_buffer_timer := 0.0
var _was_holding_item := false
## Consumed once by a physical spring/note launch, preserving native states.
var external_launch_speed := 0.0


func start() -> Script:
	super()
	_jump_buffer = _JumpBufferType.NONE
	_jump_buffer_timer = 0
	_long_jump = true
	_grav_comp = Utility.find_child_by_class(player, GravityComponent)
	_grav_comp.gravity = Vector2(0, player.long_jump_gravity)
	_was_holding_item = player.held_item != null
	
	player.sounds.stream = preload("uid://bhxmp70u556sv")
	player.sounds.play()
	
	# apply jump speed
	# OpenWE checks speed, independently of the Run key: abs(hspeed)>2.8,
	# then round(hspeed/2). The thresholds become 168 and 60 px/s.
	if absf(player.velocity.x) < 60.0:
		player.velocity.y = -player.idle_jump_speed
	elif absf(player.velocity.x) > 168.0:
		player.velocity.y = -player.fast_jump_speed
	else:
		player.velocity.y = -player.slow_jump_speed
	if external_launch_speed > 0:
		player.velocity.y = -external_launch_speed
		external_launch_speed = 0
		_long_jump = Input.is_action_pressed("player_jump")
		_grav_comp.gravity.y = player.long_jump_gravity if _long_jump else player.gravity
		player.sounds.stop()
	
	return null


func end() -> void:
	super()
	# reset gravity
	var grav = Utility.find_child_by_class(player, GravityComponent)
	grav.gravity = Vector2(0, player.gravity)


func physics_process(delta: float) -> Script:
	var direction = Input.get_axis("player_left", "player_right")
	
	# jump buffer stuff
	if _jump_buffer != _JumpBufferType.NONE:
		_jump_buffer_timer += delta
		# time's up!
		if _jump_buffer_timer > player.jump_buffer_time:
			_jump_buffer = _JumpBufferType.NONE
	if Input.is_action_just_pressed("player_jump"):
		_jump_buffer = _JumpBufferType.JUMP
		_jump_buffer_timer = 0
	elif Input.is_action_just_pressed("player_spin_jump") and not player.is_ducking():
		_jump_buffer = _JumpBufferType.SPIN_JUMP
		_jump_buffer_timer = 0
	
	if (not Input.is_action_pressed("player_jump")
			and (not Input.is_action_pressed("player_spin_jump")
			or not _was_holding_item)) \
			or player.velocity.y >= -player.long_jump_stop_speed:
		_long_jump = false
	
	if player.is_on_floor():
		# jump if the player jumped close enough
		if _jump_buffer == _JumpBufferType.JUMP:
			return PlayerJumpingState
		elif _jump_buffer == _JumpBufferType.SPIN_JUMP:
			return PlayerSpinJumpingState
		elif direction == 0:
			return PlayerIdleState
		else:
			return PlayerMovingState
	
	# change gravity for variable jump height
	if _long_jump:
		_grav_comp.gravity = Vector2(0, player.long_jump_gravity)
	else:
		_grav_comp.gravity = Vector2(0, player.gravity)
	
	position_held_item(direction)
	
	# accelerate
	apply_horizontal_motion(direction, delta)
	
	if player.can_change_sprite():
		# animations
		if player.held_item != null:
			player.sprite.play("hold_airborne")
		elif player.velocity.y < 0:
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
