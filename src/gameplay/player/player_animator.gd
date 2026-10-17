class_name PlayerAnimator
extends RefCounted
## REQ-PHYS-110~112, REQ-AST-008.

var profile: PlayerPhysicsProfile
var current_fps: float = 0.0
var fire_placeholder: bool = false
var _sprite: AnimatedSprite2D
var _small: SpriteFrames
var _super: SpriteFrames
var _fire: SpriteFrames
var _stride_phase: float = 0.0
var _time_phase: float = 0.0
var _animation: StringName = &""
var _fire_tint: Color
var _shoot_left: int = 0


func _init(sprite: AnimatedSprite2D, physics: PlayerPhysicsProfile, super_frames: SpriteFrames, fire_frames: SpriteFrames, fire_tint: Color) -> void:
	_sprite = sprite
	profile = physics
	_small = sprite.sprite_frames
	_super = super_frames
	_fire = fire_frames
	_fire_tint = fire_tint
	_sprite.stop()


func render(motion: PlayerMotion, power: PowerUpManager, horizontal_distance: float, delta: float, frozen: bool = false, carrying: bool = false, looking_up: bool = false) -> void:
	var visual_form: PowerUpManager.Form = power.form
	if power.is_transforming() and floori(float(power.transition_left) / float(profile.flash_interval_frames)) % 2 == 0:
		visual_form = power.transition_from
	var frames: SpriteFrames = _small
	if visual_form == PowerUpManager.Form.SUPER or visual_form == PowerUpManager.Form.FIRE:
		frames = _super if _super != null else _small
	if visual_form == PowerUpManager.Form.FIRE and _fire != null:
		frames = _fire
	fire_placeholder = visual_form == PowerUpManager.Form.FIRE and _fire == null
	_sprite.modulate = _fire_tint if fire_placeholder else Color.WHITE
	_sprite.visible = power.invulnerability_left == 0 or floori(float(power.invulnerability_left) / float(profile.flash_interval_frames)) % 2 == 0
	_sprite.flip_h = motion.facing < 0.0
	var name: StringName = _select_animation(motion, looking_up)
	if visual_form == PowerUpManager.Form.FIRE and not carrying and _shoot_left > 0 and motion.state in [PlayerMovementStateMachine.State.IDLE, PlayerMovementStateMachine.State.RUN] and frames.has_animation(&"shoot"):
		name = &"shoot"
	if carrying and frames.has_animation(StringName(String(name) + "_hold")):
		name = StringName(String(name) + "_hold")
	if not frames.has_animation(name):
		name = &"jump" if motion.state == PlayerMovementStateMachine.State.AIR and frames.has_animation(&"jump") else &"idle"
	if not frames.has_animation(name):
		return
	if frames != _sprite.sprite_frames or name != _animation:
		_sprite.sprite_frames = frames
		_sprite.animation = name
		_animation = name
		_time_phase = 0.0
	_sprite.pause()
	var count: int = frames.get_frame_count(name)
	if count <= 0:
		return
	var moving: bool = name == &"walk" or name == &"run" or name == &"walk_hold" or name == &"run_hold"
	current_fps = 0.0
	var phase: float = 0.0
	if moving:
		if not frozen:
			_stride_phase += absf(horizontal_distance) / profile.animation_stride
		current_fps = absf(motion.velocity.x) / profile.animation_stride if not frozen else 0.0
		phase = _stride_phase
	else:
		if name == &"spin_jump":
			current_fps = profile.spin_animation_fps
		elif name == &"dead":
			current_fps = profile.death_animation_fps
		if not frozen:
			_time_phase += current_fps * delta
		phase = _time_phase
	var frame_position: float = fposmod(phase, float(count))
	_sprite.set_frame_and_progress(floori(frame_position), frame_position - floorf(frame_position))
	if not frozen and delta > 0.0:
		_shoot_left = maxi(0, _shoot_left - 1)


func show_shoot(frames: int) -> void:
	_shoot_left = maxi(0, frames)


func _select_animation(motion: PlayerMotion, looking_up: bool) -> StringName:
	match motion.state:
		PlayerMovementStateMachine.State.DEAD: return &"dead"
		PlayerMovementStateMachine.State.AIR:
			if motion.crouch_jump or motion.crouched:
				return &"duck"
			if motion.jump_kind == PlayerMotion.JumpKind.FULL_SPEED:
				return &"p_jump"
			if motion.spin_active:
				return &"spin_jump"
			return &"fall" if motion.velocity.y >= 0.0 else &"jump"
		PlayerMovementStateMachine.State.CROUCH: return &"duck"
		PlayerMovementStateMachine.State.SKID: return &"skid"
		PlayerMovementStateMachine.State.RUN: return &"run" if profile.is_full_speed(motion.velocity.x) else &"walk"
	return &"look_up" if looking_up else &"idle"


func reset() -> void:
	_shoot_left = 0
	_stride_phase = 0.0
	_time_phase = 0.0
	_animation = &""
	_sprite.visible = true
