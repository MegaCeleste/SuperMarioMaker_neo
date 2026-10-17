extends Node
## Targeted verification of the reference integration and retained pose/input rules.
## Runs real Player collisions on synthetic ground; does not replace human playtest.

const DT: float = 1.0 / 60.0
const PLAYER_SCENE: PackedScene = preload("res://src/gameplay/player/player.tscn")

var _player: Player
var _phase: String = "settle"
var _frames: int = 0
var _start_y: float = 0.0
var _minimum_y: float = 0.0
var _apex_frame: int = 0
var _jump_frames: int = 0
var _checks: int = 0
var _failures: PackedStringArray = []
var _results: Dictionary = {}


func _ready() -> void:
	process_physics_priority = 1000
	_verify_motion_boundaries()
	var floor_body: StaticBody2D = StaticBody2D.new()
	floor_body.position = Vector2(0.0, 208.0)
	floor_body.collision_layer = CollisionConfig.layer("solids")
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(10000.0, 32.0)
	shape.shape = rectangle
	floor_body.add_child(shape)
	add_child(floor_body)
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = Vector2(80.0, 176.0)
	add_child(_player)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _verify_motion_boundaries() -> void:
	var p: PlayerPhysicsProfile = load("res://data/physics/base_physics.tres")
	var old: PlayerPhysicsProfile = load("res://data/physics/pre_smmwe_physics.tres")
	_check(p.validation_errors().is_empty() and old.validation_errors().is_empty(), "Both profiles validate")
	for start: float in [29.0, 30.0, 168.0, 168.1]:
		var m: PlayerMotion = PlayerMotion.new(p)
		m.velocity.x = start
		var f: PlayerInputFrame = PlayerInputFrame.new()
		f.axis = 1.0
		f.run = true
		f.jump = true
		f.jump_pressed = true
		m.queue_jump(f, true)
		m.begin_tick(f, true, false, DT)
		var expected: float = -231.0 if start < 30.0 else (-237.0 if start <= 168.0 else -252.0)
		_check(is_equal_approx(m.velocity.y, expected), "Jump tier uses speed before horizontal update at %s" % start)
	var buffered: PlayerMotion = PlayerMotion.new(p)
	var jump: PlayerInputFrame = PlayerInputFrame.new()
	jump.jump = true
	jump.jump_pressed = true
	buffered.queue_jump(jump, true)
	buffered.begin_tick(jump, false, false, DT)
	buffered.finish_tick(Vector2.ZERO, true, false, jump)
	_check(is_equal_approx(buffered.velocity.y, -237.0), "Landing consumes the buffered request")
	_check(buffered.buffer_left == 0, "Landing clears the consumed buffer")
	jump.jump_pressed = false
	buffered.begin_tick(jump, false, false, DT)
	_check(is_equal_approx(buffered.velocity.y, -231.0), "Buffered launch integrates gravity on its first moving frame")
	jump.jump = false
	jump.jump_released = true
	buffered.queue_jump(jump, true)
	buffered.begin_tick(jump, false, false, DT)
	_check(is_equal_approx(buffered.velocity.y, -213.0), "Release selects short-jump gravity")
	jump.jump = true
	jump.jump_released = false
	buffered.begin_tick(jump, false, false, DT)
	_check(is_equal_approx(buffered.velocity.y, -195.0), "Re-holding cannot restore low gravity")
	var source_key: PlayerMotion = PlayerMotion.new(p)
	jump.jump_pressed = true
	source_key.queue_jump(jump, true)
	source_key.begin_tick(jump, true, false, DT)
	jump.jump_pressed = false
	jump.spin_released = true
	source_key.queue_jump(jump, true)
	source_key.begin_tick(jump, false, false, DT)
	_check(is_equal_approx(source_key.velocity.y, -225.0), "Unrelated spin release does not shorten a normal jump")
	var apex: PlayerMotion = PlayerMotion.new(p)
	jump.spin_released = false
	jump.jump_pressed = true
	apex.queue_jump(jump, true)
	apex.begin_tick(jump, true, false, DT)
	jump.jump_pressed = false
	apex.velocity.y = -30.0
	apex.begin_tick(jump, false, false, DT)
	_check(is_equal_approx(apex.velocity.y, -24.0), "At -30 the held jump still uses low gravity")
	apex.begin_tick(jump, false, false, DT)
	_check(is_equal_approx(apex.velocity.y, -6.0), "Above -30 gravity switches before the apex")
	apex.velocity.y = -60.0
	apex.begin_tick(jump, false, false, DT)
	_check(is_equal_approx(apex.velocity.y, -42.0), "Apex transition remains latched")
	var fall: PlayerMotion = PlayerMotion.new(p)
	fall.velocity.y = 500.0
	fall.begin_tick(PlayerInputFrame.new(), false, false, DT)
	_check(is_equal_approx(fall.velocity.y, 258.0), "Terminal threshold clamps before gravity")
	fall.head_bump()
	_check(is_zero_approx(fall.velocity.y), "Head bump zeros vertical velocity")
	fall.bounce(PlayerInputFrame.new())
	_check(is_equal_approx(fall.velocity.y, -253.5), "Released stomp has the reference initial speed")
	fall.bounce(jump)
	_check(is_equal_approx(fall.velocity.y, -253.5), "Held stomp changes gravity instead of initial speed")
	var fallback: PlayerMotion = PlayerMotion.new(p)
	var spin_input: PlayerInputFrame = PlayerInputFrame.new()
	spin_input.spin = true
	spin_input.spin_pressed = true
	fallback.queue_jump(spin_input, false)
	fallback.begin_tick(spin_input, true, false, DT)
	_check(not fallback.spin_active, "Unsupported spin falls back to a normal jump")
	fallback.bounce(spin_input)
	fallback.begin_tick(spin_input, false, false, DT)
	_check(is_equal_approx(fallback.velocity.y, -247.5), "Fallback spin key remains the held bounce source")
	spin_input.spin = false
	spin_input.spin_released = true
	fallback.queue_jump(spin_input, false)
	fallback.begin_tick(spin_input, false, false, DT)
	_check(is_equal_approx(fallback.velocity.y, -229.5), "Releasing the fallback spin key shortens its bounce")
	fall.enter_dead()
	fall.begin_tick(jump, true, false, DT)
	_check(fall.state == PlayerMovementStateMachine.State.DEAD and fall.velocity == Vector2.ZERO, "Death blocks motion")
	fall.reset()
	_check(fall.velocity == Vector2.ZERO and fall.buffer_left == 0 and not fall.crouch_jump, "Reset clears motion latches")


func _set_action(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	_player.record_input_event(event)


func _begin_jump(phase: String) -> void:
	_phase = phase
	_jump_frames = 0
	_apex_frame = 0
	_start_y = _player.feet_y()
	_minimum_y = _start_y
	_set_action(&"jump", true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames > 700:
		_check(false, "Collision probe timed out in " + _phase)
		_finish()
		return
	match _phase:
		"settle":
			if _frames > 5 and _player.is_on_floor():
				_begin_jump("standing")
		"standing", "full_speed", "crouch":
			_jump_frames += 1
			if _player.feet_y() < _minimum_y:
				_minimum_y = _player.feet_y()
				_apex_frame = _jump_frames
			if _phase == "full_speed" and not _player.is_on_floor():
				_check(_player.motion.jump_kind == PlayerMotion.JumpKind.FULL_SPEED, "Full-speed jump pose stays latched while reversing")
				if _jump_frames == 1:
					_set_action(&"move_right", false)
					_set_action(&"move_left", true)
					_set_action(&"run", false)
			if _phase == "crouch" and not _player.is_on_floor():
				_check(_player.motion.crouch_jump and _player.collisions.crouched, "Crouch jump retains its body shape after releasing down")
				if _jump_frames == 1:
					_set_action(&"move_down", false)
			if _jump_frames > 1 and _player.is_on_floor():
				var height: float = _start_y - _minimum_y
				_results[_phase] = {"height_px": height, "apex_frame": _apex_frame, "air_frames": _jump_frames}
				_set_action(&"jump", false)
				if _phase == "standing":
					_check(absf(height - 75.4) < 0.05 and _apex_frame == 36, "Actual floor collision standing curve matches the reference")
					_phase = "accelerate"
					_set_action(&"move_right", true)
					_set_action(&"run", true)
				elif _phase == "full_speed":
					_check(absf(height - 89.8) < 0.05 and _apex_frame == 40, "Actual floor collision full-speed curve matches the reference")
					_check(_player.motion.jump_kind == PlayerMotion.JumpKind.NORMAL, "Landing clears full-speed jump pose")
					_set_action(&"move_left", false)
					_phase = "stop"
				else:
					_check(not _player.motion.crouch_jump and not _player.collisions.crouched, "Landing clears crouch jump")
					_verify_dashboard()
					_finish()
		"accelerate":
			if _player.physics_profile.is_full_speed(_player.velocity.x):
				_begin_jump("full_speed")
		"stop":
			if is_zero_approx(_player.velocity.x) and _player.is_on_floor():
				_set_action(&"move_down", true)
				_phase = "duck"
		"duck":
			if _player.collisions.crouched:
				_begin_jump("crouch")


func _verify_dashboard() -> void:
	var dashboard: Node = load("res://src/gameplay/debug/physics_dashboard.tscn").instantiate()
	add_child(dashboard)
	var actor: Player = dashboard.get("_player") as Player
	dashboard.call("_on_physics_selected", 1)
	_check(actor.physics_profile.motion_model == PlayerPhysicsProfile.MotionModel.LEGACY and is_equal_approx(actor.physics_profile.jump_initial, -360.0), "Dashboard restores the complete previous profile")
	_check(actor.motion.profile == actor.physics_profile and actor.collisions.profile == actor.physics_profile, "Profile selection preserves shared module references")
	var controls: Dictionary = dashboard.get("_parameter_controls")
	_check(not (controls["air_reverse_accel"] as SpinBox).editable, "Reference-only tuning is disabled for the old model")
	dashboard.call("_restore_baseline")
	_check(actor.physics_profile.motion_model == PlayerPhysicsProfile.MotionModel.SMMWE and is_equal_approx(actor.physics_profile.air_reverse_accel, 468.0), "Restore baseline returns to the reference profile")
	_check((controls["air_reverse_accel"] as SpinBox).editable, "Reference-only tuning reactivates for the reference model")
	_check(is_equal_approx((controls["ground_accel"] as SpinBox).value, 216.0) and is_equal_approx((controls["jump_initial"] as SpinBox).value, -237.0), "Tuner shows reference values without step rounding")
	remove_child(dashboard)
	dashboard.queue_free()


func _finish() -> void:
	set_physics_process(false)
	for action: StringName in [&"move_left", &"move_right", &"move_down", &"run", &"jump"]:
		Input.action_release(action)
	_results["checks"] = _checks
	_results["failures"] = Array(_failures)
	_results["human_playtest"] = false
	var file: FileAccess = FileAccess.open("res://local_debug_output/smmwe-sync/boundary-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(_results, "  "))
	print("SMMWE sync: %s checks, %s failures, real floor curves %s" % [_checks, _failures.size(), _results])
	# Let nodes removed during the physics callback and their UI work finish.
	call_deferred("_quit_after_cleanup")


func _quit_after_cleanup() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)
