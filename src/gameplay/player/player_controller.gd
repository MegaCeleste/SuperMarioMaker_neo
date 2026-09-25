class_name PlayerController
extends CharacterBody2D

signal movement_state_changed(previous: MovementState, current: MovementState)
signal p_meter_changed(previous: int, current: int)

enum MovementState { IDLE, RUN, AIR, CROUCH, SKID, DEAD }
enum PowerForm { SMALL, SUPER }

const STYLE_ABILITIES_PATH := "res://data/physics/style_abilities.json"
const CEILING_NORMAL_MIN := 0.5

@export var physics_profile: PlayerPhysicsProfile = preload("res://data/physics/base_physics.tres")
@export_enum("smb1", "smb3", "smw") var style_id: String = "smw"
@export var super_sprite_frames: SpriteFrames

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var standing_shape: CollisionShape2D = $StandingShape
@onready var duck_shape: CollisionShape2D = $DuckShape
var state_machine: StateMachine  # Parse-only compatibility for disconnected legacy scripts.
@onready var klock_sound: AudioStreamPlayer2D = $Sound/KlockSound
@onready var jump_sound: AudioStreamPlayer2D = $Sound/JumpSound
@onready var skid_sound: AudioStreamPlayer2D = $Sound/SkidSound
@onready var dead_sound: AudioStreamPlayer2D = $Sound/DeadSound
@onready var spin_jump_sound: AudioStreamPlayer2D = $Sound/SpinJumpSound
@onready var powerup_sound: AudioStreamPlayer2D = $Sound/PowerupSound

var movement_state: MovementState = MovementState.AIR
var power_form: PowerForm = PowerForm.SMALL
var p_meter: int = 0
var is_priming_jump: bool = false

var _small_sprite_frames: SpriteFrames
var _style_abilities: Dictionary = {}
var _coyote_left: int = 0
var _jump_buffer_left: int = 0
var _spin_buffered: bool = false
var _spin_active: bool = false
var _jumped_since_floor: bool = false
var _crouch_pose_active: bool = false
var _crouch_jump_active: bool = false
var _crouch_jump_pending: bool = false
var _skid_active: bool = false
var _p_meter_direction: float = 0.0

# Accessors keep the disconnected legacy scripts parseable until their removal.
var ground_acceleration: float:
	get: return physics_profile.ground_accel
var max_walk_speed: float:
	get: return physics_profile.walk_max
var max_run_speed: float:
	get: return physics_profile.run_max
var air_acceleration: float:
	get: return physics_profile.ground_accel * physics_profile.air_accel_factor
var max_fall_speed: float:
	get: return physics_profile.max_fall
var JUMP_VELOCITY: float:
	get: return physics_profile.jump_initial
var SUPER_JUMP_VELOCITY: float:
	get: return physics_profile.super_jump_initial
var SPIN_JUMP_VELOCITY: float:
	get: return physics_profile.spin_jump_initial


func _ready() -> void:
	collision_layer = CollisionConfig.layer("player")
	collision_mask = CollisionConfig.mask(["solids", "enemies", "semisolids"])
	_small_sprite_frames = animated_sprite.sprite_frames
	standing_shape.shape = standing_shape.shape.duplicate()
	duck_shape.shape = duck_shape.shape.duplicate()
	_load_style_abilities()
	_apply_hitbox()
	_update_animation()


func _physics_process(delta: float) -> void:
	if movement_state == MovementState.DEAD:
		return
	var grounded_before: bool = is_on_floor()
	var direction: float = Input.get_axis("move_left", "move_right")
	var run_held: bool = Input.is_action_pressed("run")
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("spin_jump"):
		_jump_buffer_left = physics_profile.jump_buffer_frames
		_spin_buffered = Input.is_action_just_pressed("spin_jump") and has_ability("spin_jump")
	if grounded_before:
		_coyote_left = physics_profile.coyote_frames
		_jumped_since_floor = false
		_spin_active = false
		is_priming_jump = false
	_set_crouched((Input.is_action_pressed("move_down") and grounded_before) or _crouch_jump_active)
	if _is_crouched() and (Input.is_action_pressed("jump") or Input.is_action_pressed("spin_jump")):
		_crouch_jump_pending = true
	elif not Input.is_action_pressed("jump") and not Input.is_action_pressed("spin_jump"):
		_crouch_jump_pending = false
	if direction != 0.0:
		animated_sprite.flip_h = direction < 0.0
	var speed_before: float = absf(velocity.x)
	if grounded_before:
		if _is_crouched() or direction == 0.0:
			_skid_active = false
			velocity.x = move_toward(velocity.x, 0.0, physics_profile.friction_normal * delta)
			if _is_crouched():
				_set_p_meter(0)
			else:
				_decay_p_meter()
		else:
			var opposite: bool = not is_zero_approx(velocity.x) and signf(velocity.x) != signf(direction)
			if opposite and absf(velocity.x) >= physics_profile.skid_threshold:
				_skid_active = true
			if not opposite:
				_skid_active = false
			var acceleration: float = physics_profile.skid_decel if _skid_active else physics_profile.ground_accel
			var limit: float = physics_profile.p_speed if is_p_running() and run_held else (physics_profile.run_max if run_held else physics_profile.walk_max)
			velocity.x = move_toward(velocity.x, direction * limit, acceleration * delta)
			if _skid_active:
				_set_p_meter(0)
			elif has_ability("p_meter") and run_held and speed_before >= physics_profile.run_max and signf(velocity.x) == signf(direction):
				_p_meter_direction = signf(direction)
				_set_p_meter(p_meter + physics_profile.p_meter_charge_per_frame)
			else:
				_decay_p_meter()
			if is_zero_approx(velocity.x) or signf(velocity.x) == signf(direction):
				_skid_active = false
	elif direction != 0.0:
		_skid_active = false
		var air_limit: float = physics_profile.p_speed if is_p_running() and run_held else (physics_profile.run_max if run_held else physics_profile.walk_max)
		velocity.x = move_toward(velocity.x, direction * air_limit, air_acceleration * delta)
		if signf(direction) != _p_meter_direction:
			_decay_p_meter()
	else:
		_skid_active = false
		_decay_p_meter()
	if _jump_buffer_left > 0 and (grounded_before or _coyote_left > 0) and not _jumped_since_floor:
		_start_jump()
	if not grounded_before or velocity.y < 0.0:
		var jump_held: bool = Input.is_action_pressed("jump") or Input.is_action_pressed("spin_jump")
		var gravity: float = physics_profile.gravity_rise if velocity.y < 0.0 and jump_held else physics_profile.gravity_fall
		velocity.y = minf(velocity.y + gravity * delta, physics_profile.max_fall)
	_attempt_corner_correction(delta)
	move_and_slide()
	if is_on_wall():
		_set_p_meter(0)
	_handle_ceiling_collision()
	if is_on_floor():
		_coyote_left = physics_profile.coyote_frames
		if not grounded_before:
			_jumped_since_floor = false
			_spin_active = false
			is_priming_jump = false
			_crouch_jump_active = false
			_set_crouched(Input.is_action_pressed("move_down"))
			if _jump_buffer_left > 0:
				_start_jump()
	else:
		_coyote_left = maxi(_coyote_left - 1, 0)
	if _jump_buffer_left > 0:
		_jump_buffer_left -= 1
		if _jump_buffer_left == 0:
			_spin_buffered = false
	if not is_on_floor() or velocity.y < 0.0:
		_set_movement_state(MovementState.AIR)
	elif _is_crouched():
		_set_movement_state(MovementState.CROUCH)
	elif _skid_active:
		_set_movement_state(MovementState.SKID)
	elif not is_zero_approx(velocity.x):
		_set_movement_state(MovementState.RUN)
	else:
		_set_movement_state(MovementState.IDLE)
	_update_animation()


func _start_jump() -> void:
	_spin_active = _spin_buffered
	is_priming_jump = is_p_running() and not _spin_active
	_crouch_jump_active = _crouch_jump_pending or _is_crouched()
	_crouch_jump_pending = false
	_set_crouched(_crouch_jump_active)
	velocity.y = physics_profile.spin_jump_initial if _spin_active else (physics_profile.super_jump_initial if is_priming_jump else physics_profile.jump_initial)
	_jump_buffer_left = 0
	_coyote_left = 0
	_jumped_since_floor = true
	_spin_buffered = false
	_set_movement_state(MovementState.AIR)
	_play_sound(spin_jump_sound if _spin_active else jump_sound)


func _attempt_corner_correction(delta: float) -> void:
	if velocity.y >= 0.0:
		return
	var rise: Vector2 = Vector2(0.0, velocity.y * delta)
	if not test_move(global_transform, rise):
		return
	for offset: int in range(1, floori(physics_profile.corner_correction_max) + 1):
		for side: int in [-1, 1]:
			var shift: Vector2 = Vector2(float(offset * side), 0.0)
			if not test_move(global_transform, shift) and not test_move(global_transform.translated(shift), rise):
				global_position += shift
				return


func _handle_ceiling_collision() -> void:
	if not is_on_ceiling():
		return
	var closest_block: InteractableBlock = null
	var largest_overlap: float = -1.0
	var player_left: float = global_position.x - physics_profile.hitbox_width / 2.0
	var player_right: float = global_position.x + physics_profile.hitbox_width / 2.0
	for index: int in get_slide_collision_count():
		var collision: KinematicCollision2D = get_slide_collision(index)
		if collision.get_normal().y <= CEILING_NORMAL_MIN:
			continue
		var collider: Object = collision.get_collider()
		if collider is InteractableBlock:
			var block: InteractableBlock = collider as InteractableBlock
			var block_shape: CollisionShape2D = block.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if block_shape == null or not block_shape.shape is RectangleShape2D:
				continue
			var rectangle: RectangleShape2D = block_shape.shape as RectangleShape2D
			var block_left: float = block_shape.global_position.x - rectangle.size.x / 2.0
			var block_right: float = block_shape.global_position.x + rectangle.size.x / 2.0
			var overlap: float = maxf(0.0, minf(player_right, block_right) - maxf(player_left, block_left))
			if overlap > largest_overlap:
				largest_overlap = overlap
				closest_block = block
	velocity.y = physics_profile.head_bump_speed
	if closest_block != null:
		closest_block.hit_by_player(self as Player)


func _set_crouched(requested: bool) -> void:
	_crouch_pose_active = requested or (_crouch_pose_active and not _can_stand())
	var use_duck_shape: bool = _crouch_pose_active and power_form == PowerForm.SUPER
	standing_shape.disabled = use_duck_shape
	duck_shape.disabled = not use_duck_shape
	if _crouch_pose_active:
		_set_p_meter(0)


func _is_crouched() -> bool:
	return _crouch_pose_active


func _can_stand() -> bool:
	if power_form == PowerForm.SMALL:
		return true
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = standing_shape.shape
	query.transform = global_transform.translated(standing_shape.position)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _apply_hitbox() -> void:
	var height: float = physics_profile.super_height if power_form == PowerForm.SUPER else physics_profile.small_height
	var stand_rect: RectangleShape2D = standing_shape.shape as RectangleShape2D
	var duck_rect: RectangleShape2D = duck_shape.shape as RectangleShape2D
	stand_rect.size = Vector2(physics_profile.hitbox_width, height)
	duck_rect.size = Vector2(physics_profile.hitbox_width, physics_profile.crouch_height)
	standing_shape.position.y = physics_profile.feet_y - height / 2.0
	duck_shape.position.y = physics_profile.feet_y - physics_profile.crouch_height / 2.0


func _set_movement_state(next: MovementState) -> void:
	if movement_state == next:
		return
	var previous: MovementState = movement_state
	movement_state = next
	movement_state_changed.emit(previous, next)
	if next == MovementState.SKID:
		_play_sound(skid_sound)


func _set_p_meter(value: int) -> void:
	var next_value: int = clampi(value, 0, physics_profile.p_meter_max) if has_ability("p_meter") else 0
	if next_value == p_meter:
		return
	var previous: int = p_meter
	p_meter = next_value
	if p_meter == 0:
		_p_meter_direction = 0.0
	p_meter_changed.emit(previous, p_meter)


func _decay_p_meter() -> void:
	_set_p_meter(p_meter - physics_profile.p_meter_decay_per_frame)


func is_p_running() -> bool:
	return has_ability("p_meter") and p_meter >= physics_profile.p_meter_max


func get_movement_animation_fps(speed: float) -> float:
	var absolute_speed: float = absf(speed)
	if absolute_speed <= physics_profile.anim_low_speed:
		return lerpf(0.0, physics_profile.anim_low_fps, absolute_speed / maxf(physics_profile.anim_low_speed, 0.001))
	if absolute_speed <= physics_profile.walk_max:
		return lerpf(physics_profile.anim_low_fps, physics_profile.anim_walk_fps, (absolute_speed - physics_profile.anim_low_speed) / maxf(physics_profile.walk_max - physics_profile.anim_low_speed, 0.001))
	if absolute_speed <= physics_profile.run_max:
		return lerpf(physics_profile.anim_walk_fps, physics_profile.anim_run_fps, (absolute_speed - physics_profile.walk_max) / maxf(physics_profile.run_max - physics_profile.walk_max, 0.001))
	return lerpf(physics_profile.anim_run_fps, physics_profile.anim_p_fps, clampf((absolute_speed - physics_profile.run_max) / maxf(physics_profile.p_speed - physics_profile.run_max, 0.001), 0.0, 1.0))


func get_current_animation_fps() -> float:
	if animated_sprite.sprite_frames == null:
		return 0.0
	return animated_sprite.sprite_frames.get_animation_speed(animated_sprite.animation) * animated_sprite.speed_scale


func _update_animation() -> void:
	var animation_name: StringName = &"idle"
	match movement_state:
		MovementState.AIR:
			if _crouch_jump_active:
				animation_name = &"duck"
			else:
				if _spin_active:
					animation_name = &"spin_jump"
				elif velocity.y >= 0.0:
					animation_name = &"fall"
				elif is_priming_jump and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(&"p_jump"):
					animation_name = &"p_jump"
				else:
					animation_name = &"jump"
		MovementState.CROUCH: animation_name = &"duck"
		MovementState.SKID: animation_name = &"skid"
		MovementState.RUN: animation_name = &"run" if absf(velocity.x) >= physics_profile.run_max else &"walk"
		MovementState.DEAD: animation_name = &"dead"
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(animation_name):
		if animation_name == &"walk" or animation_name == &"run":
			var base_fps: float = animated_sprite.sprite_frames.get_animation_speed(animation_name)
			animated_sprite.speed_scale = get_movement_animation_fps(velocity.x) / maxf(base_fps, 0.001)
		else:
			animated_sprite.speed_scale = 1.0
		if animated_sprite.animation != animation_name:
			animated_sprite.play(animation_name)


func _load_style_abilities() -> void:
	var file: FileAccess = FileAccess.open(STYLE_ABILITIES_PATH, FileAccess.READ)
	if file == null:
		push_error("Missing style abilities: " + STYLE_ABILITIES_PATH)
		return
	var document: Variant = JSON.parse_string(file.get_as_text())
	if document is Dictionary and document.has(style_id):
		_style_abilities = document[style_id] as Dictionary
	else:
		push_error("Unknown style ID: " + style_id)


func has_ability(ability: String) -> bool:
	return bool(_style_abilities.get(ability, false))


func set_form(form: PowerForm) -> void:
	if form == power_form or movement_state == MovementState.DEAD:
		return
	power_form = form
	if form == PowerForm.SMALL:
		_set_p_meter(0)
	animated_sprite.sprite_frames = super_sprite_frames if form == PowerForm.SUPER and super_sprite_frames != null else _small_sprite_frames
	call_deferred("_finish_form_change")
	if form == PowerForm.SUPER:
		_play_sound(powerup_sound)


func _finish_form_change() -> void:
	_apply_hitbox()
	_set_crouched(power_form == PowerForm.SUPER and not _can_stand())
	_update_animation()


func collect_mushroom() -> void:
	set_form(PowerForm.SUPER)


func bounce() -> void:
	if movement_state == MovementState.DEAD:
		return
	velocity.y = physics_profile.jump_initial
	_coyote_left = 0
	_jumped_since_floor = true
	_set_movement_state(MovementState.AIR)
	_play_sound(klock_sound)


func die() -> void:
	if movement_state == MovementState.DEAD:
		return
	velocity = Vector2.ZERO
	_set_p_meter(0)
	_set_movement_state(MovementState.DEAD)
	standing_shape.set_deferred("disabled", true)
	duck_shape.set_deferred("disabled", true)
	_play_sound(dead_sound)
	_update_animation()


func _play_sound(sound: AudioStreamPlayer2D) -> void:
	if sound.stream != null:
		sound.play()
