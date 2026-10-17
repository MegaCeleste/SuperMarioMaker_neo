class_name PlayerMotion
extends RefCounted
## REQ-PHYS-101~103/106/109/111~114. No scene nodes or Input API.

signal state_changed(previous: PlayerMovementStateMachine.State, current: PlayerMovementStateMachine.State)
signal jump_started(kind: JumpKind, horizontal_speed: float, vertical_speed: float)
signal meter_changed(previous: int, current: int)

enum JumpKind { NORMAL, FULL_SPEED, SPIN, CROUCH, BOUNCE }

var profile: PlayerPhysicsProfile
var velocity: Vector2 = Vector2.ZERO
var state_machine: PlayerMovementStateMachine:
	get: return _state_machine
	set(_value): push_error("PlayerMotion.state_machine cannot be replaced.")
var state: PlayerMovementStateMachine.State:
	get: return state_machine.current
	set(_value): push_error("PlayerMotion.state is read only; the movement state machine owns transitions.")
var facing: float = 1.0
var jump_kind: JumpKind = JumpKind.NORMAL
var spin_active: bool = false
var crouch_jump: bool = false
var crouched: bool = false
var p_meter: int = 0
var coyote_left: int = 0
var buffer_left: int = 0
var skidding: bool = false
var speed_bonus: float = 0.0

var _state_machine: PlayerMovementStateMachine = PlayerMovementStateMachine.new()
var _buffer_spin: bool = false
var _buffer_hold_from_spin: bool = false
var _hold_from_spin: bool = false
var _hold_allowed: bool = false
var _jumped_since_floor: bool = false
var _skip_gravity_once: bool = false
var _meter_direction: float = 0.0


func _init(physics: PlayerPhysicsProfile) -> void:
	profile = physics
	_state_machine.state_changed.connect(_on_state_changed)


func queue_jump(input: PlayerInputFrame, allow_spin: bool) -> void:
	if state == PlayerMovementStateMachine.State.DEAD:
		return
	var released: bool = input.spin_released if _hold_from_spin else input.jump_released
	if released:
		_hold_allowed = false
	if input.jump_pressed or input.spin_pressed:
		buffer_left = profile.jump_buffer_frames
		_buffer_hold_from_spin = input.spin_pressed and not input.jump_pressed
		_buffer_spin = _buffer_hold_from_spin and allow_spin


func begin_tick(input: PlayerInputFrame, grounded: bool, meter_enabled: bool, delta: float) -> void:
	if state == PlayerMovementStateMachine.State.DEAD:
		return
	if grounded:
		coyote_left = profile.coyote_frames
		_jumped_since_floor = false
		spin_active = false
		crouch_jump = false
		jump_kind = JumpKind.NORMAL
	if not is_zero_approx(input.axis):
		facing = signf(input.axis)
	var reference: bool = profile.motion_model == PlayerPhysicsProfile.MotionModel.SMMWE
	var can_jump: bool = buffer_left > 0 and not _jumped_since_floor and (grounded or coyote_left > 0)
	# SMMWE chooses the jump tier from the incoming speed, before horizontal input.
	if reference and can_jump:
		_start_jump(input)
	_update_horizontal(input, grounded and not (reference and can_jump), delta)
	_update_meter(input, grounded, meter_enabled)
	if not reference and can_jump:
		_start_jump(input)
	if _hold_allowed and not input.jump_held(_hold_from_spin):
		_hold_allowed = false
	_update_gravity(grounded, delta)


func _update_gravity(grounded: bool, delta: float) -> void:
	if _skip_gravity_once:
		_skip_gravity_once = false
	elif not grounded or velocity.y < 0.0:
		if profile.motion_model == PlayerPhysicsProfile.MotionModel.SMMWE:
			if velocity.y > profile.apex_gravity_threshold + profile.speed_epsilon:
				_hold_allowed = false
			var gravity: float = profile.gravity_rise if _hold_allowed else profile.gravity_fall
			# GML clamps vspeed in Step before the engine adds gravity and moves.
			velocity.y = minf(velocity.y, profile.max_fall) + gravity * delta
		else:
			var gravity: float = profile.gravity_rise if velocity.y < 0.0 and _hold_allowed else profile.gravity_fall
			velocity.y = minf(velocity.y + gravity * delta, profile.max_fall)
	else:
		velocity.y = profile.gravity_fall * delta


func finish_tick(solved_velocity: Vector2, grounded: bool, wall: bool, input: PlayerInputFrame) -> void:
	if state == PlayerMovementStateMachine.State.DEAD:
		return
	velocity = solved_velocity
	if wall:
		clear_meter()
		skidding = false
	if grounded and velocity.y >= 0.0:
		coyote_left = profile.coyote_frames
		_jumped_since_floor = false
		spin_active = false
		crouch_jump = false
		jump_kind = JumpKind.NORMAL
		if buffer_left > 0:
			_start_jump(input)
	else:
		coyote_left = maxi(0, coyote_left - 1)
	buffer_left = maxi(0, buffer_left - 1)
	if buffer_left == 0:
		_buffer_spin = false
	publish_state(grounded)


func publish_state(grounded: bool) -> void:
	state_machine.resolve(grounded, crouched, skidding, velocity, profile.speed_epsilon)


func _update_horizontal(input: PlayerInputFrame, grounded: bool, delta: float) -> void:
	if profile.motion_model == PlayerPhysicsProfile.MotionModel.SMMWE:
		_update_reference_horizontal(input, grounded, delta)
		return
	var limit: float = (profile.run_max if input.run else profile.walk_max) + speed_bonus
	if grounded:
		if crouched or is_zero_approx(input.axis):
			skidding = false
			velocity.x = move_toward(velocity.x, 0.0, profile.friction_normal * delta)
			return
		var opposite: bool = absf(velocity.x) > profile.speed_epsilon and signf(velocity.x) != signf(input.axis)
		if opposite:
			skidding = skidding or absf(velocity.x) >= profile.skid_threshold
			velocity.x = move_toward(velocity.x, 0.0, profile.skid_decel * delta)
			if absf(velocity.x) <= profile.speed_epsilon:
				velocity.x = 0.0
			return
		skidding = false
		var acceleration: float = profile.friction_normal if absf(velocity.x) > limit else profile.ground_accel
		velocity.x = move_toward(velocity.x, input.axis * limit, acceleration * delta)
	else:
		skidding = false
		if is_zero_approx(input.axis):
			return
		if signf(velocity.x) == signf(input.axis) and absf(velocity.x) >= limit:
			return
		velocity.x = move_toward(velocity.x, input.axis * limit, profile.ground_accel * profile.air_accel_factor * delta)


func _update_reference_horizontal(input: PlayerInputFrame, grounded: bool, delta: float) -> void:
	var limit: float = (profile.run_max if input.run else profile.walk_max) + speed_bonus
	if grounded and crouched:
		skidding = false
		_apply_reference_friction(delta)
		return
	if is_zero_approx(input.axis):
		skidding = false
		if grounded:
			_apply_reference_friction(delta)
	else:
		var direction: float = signf(input.axis)
		var opposite: bool = velocity.x * direction < -profile.speed_epsilon
		skidding = grounded and opposite and (skidding or absf(velocity.x) >= profile.skid_threshold)
		if velocity.x * direction < limit - profile.speed_epsilon:
			var acceleration: float = profile.ground_accel if grounded else profile.ground_accel * profile.air_accel_factor
			if opposite:
				acceleration = profile.skid_decel if grounded else profile.air_reverse_accel
			# The reverse step crosses zero; the source cap is a branch threshold.
			velocity.x += direction * acceleration * delta
		if velocity.x * direction >= -profile.speed_epsilon:
			skidding = false
	if grounded and absf(velocity.x) > limit + profile.speed_epsilon:
		velocity.x = move_toward(velocity.x, 0.0, profile.ground_overspeed_decel * delta)


func _apply_reference_friction(delta: float) -> void:
	var step: float = profile.friction_normal * delta
	velocity.x = move_toward(velocity.x, 0.0, step)
	if absf(velocity.x) < step - profile.speed_epsilon:
		velocity.x = 0.0


func _start_jump(input: PlayerInputFrame) -> void:
	_hold_from_spin = _buffer_hold_from_spin
	spin_active = _buffer_spin and not crouched
	crouch_jump = crouched
	jump_kind = JumpKind.NORMAL
	if spin_active:
		jump_kind = JumpKind.SPIN
	elif crouch_jump:
		jump_kind = JumpKind.CROUCH
	elif profile.is_full_speed(velocity.x):
		jump_kind = JumpKind.FULL_SPEED
	velocity.y = profile.spin_jump_initial if spin_active else profile.normal_jump_speed(velocity.x)
	_hold_allowed = input.jump_held(_hold_from_spin)
	_skip_gravity_once = profile.motion_model == PlayerPhysicsProfile.MotionModel.LEGACY
	buffer_left = 0
	coyote_left = 0
	_jumped_since_floor = true
	_buffer_spin = false
	skidding = false
	state_machine.take_off()
	jump_started.emit(jump_kind, velocity.x, velocity.y)


func head_bump() -> void:
	if state == PlayerMovementStateMachine.State.DEAD:
		return
	velocity.y = profile.head_bump_speed
	_hold_allowed = false


func bounce(input: PlayerInputFrame) -> void:
	if state == PlayerMovementStateMachine.State.DEAD:
		return
	if profile.motion_model == PlayerPhysicsProfile.MotionModel.LEGACY:
		_hold_from_spin = spin_active
	elif not _jumped_since_floor:
		# Walking onto an enemy has no takeoff key to preserve.
		_hold_from_spin = input.spin and not input.jump
	var jump_held: bool = input.jump_held(_hold_from_spin)
	velocity.y = profile.spin_bounce_initial if spin_active else (profile.bounce_held_initial if jump_held else profile.bounce_initial)
	if spin_active:
		jump_kind = JumpKind.SPIN
	elif not crouch_jump and jump_kind != JumpKind.FULL_SPEED:
		jump_kind = JumpKind.BOUNCE
	_hold_allowed = jump_held
	_skip_gravity_once = profile.motion_model == PlayerPhysicsProfile.MotionModel.LEGACY
	_jumped_since_floor = true
	coyote_left = 0
	buffer_left = 0
	state_machine.take_off()
	jump_started.emit(JumpKind.BOUNCE, velocity.x, velocity.y)


func _update_meter(input: PlayerInputFrame, grounded: bool, enabled: bool) -> void:
	if not enabled or crouched or skidding:
		clear_meter()
	elif grounded and input.run and not is_zero_approx(input.axis) and profile.is_full_speed(velocity.x):
		_meter_direction = signf(input.axis)
		_set_meter(p_meter + profile.p_meter_charge_per_frame)
	elif not grounded and not is_zero_approx(input.axis) and signf(input.axis) == _meter_direction:
		pass
	else:
		_set_meter(p_meter - profile.p_meter_decay_per_frame)


func clear_meter() -> void:
	_set_meter(0)
	_meter_direction = 0.0


func _set_meter(value: int) -> void:
	var next: int = clampi(value, 0, profile.p_meter_max)
	if next != p_meter:
		var previous: int = p_meter
		p_meter = next
		meter_changed.emit(previous, next)


func _on_state_changed(previous: PlayerMovementStateMachine.State, current: PlayerMovementStateMachine.State) -> void:
	state_changed.emit(previous, current)


func reset() -> void:
	_clear_motion()
	state_machine.reset()


func _clear_motion() -> void:
	velocity = Vector2.ZERO
	speed_bonus = 0.0
	facing = 1.0
	jump_kind = JumpKind.NORMAL
	spin_active = false
	crouch_jump = false
	crouched = false
	skidding = false
	coyote_left = 0
	buffer_left = 0
	_buffer_spin = false
	_buffer_hold_from_spin = false
	_hold_from_spin = false
	_hold_allowed = false
	_jumped_since_floor = false
	_skip_gravity_once = false
	clear_meter()


func enter_dead() -> void:
	_clear_motion()
	state_machine.die()
