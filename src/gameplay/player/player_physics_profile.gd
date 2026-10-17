class_name PlayerPhysicsProfile
extends Resource
## REQ-PHYS-001/008. Evidence: data/physics/player_parameter_evidence.json.

enum MotionModel { LEGACY, SMMWE }

@export var motion_model: MotionModel = MotionModel.LEGACY

@export_group("Horizontal")
@export var walk_max: float = 84.0
@export var run_max: float = 180.0
@export var ground_accel: float = 225.0
@export var skid_decel: float = 540.0
@export var friction_normal: float = 225.0
@export var skid_threshold: float = 100.0
@export var air_accel_factor: float = 0.65
@export var air_reverse_accel: float = 468.0
@export var ground_overspeed_decel: float = 90.0
@export var speed_epsilon: float = 0.01

@export_group("Jump")
@export var jump_initial: float = -360.0
@export var moving_jump_initial: float = -243.0
@export var moving_jump_threshold: float = 30.0
@export var run_jump_threshold: float = 168.0
@export var run_jump_initial: float = -430.0
@export var spin_jump_initial: float = -280.0
@export var gravity_rise: float = 900.0
@export var gravity_fall: float = 1800.0
@export var max_fall: float = 270.0
@export var apex_gravity_threshold: float = -30.0
@export var coyote_frames: int = 6
@export var jump_buffer_frames: int = 5
@export var corner_correction_max: float = 3.0
@export var head_bump_speed: float = 10.0

@export_group("Terrain collision")
@export var hitbox_width: float = 12.0
@export var small_height: float = 14.0
@export var small_crouch_height: float = 14.0
@export var super_height: float = 28.0
@export var crouch_height: float = 14.0
@export var feet_y: float = 16.0
@export var collision_margin: float = 0.01
@export var clearance_epsilon: float = 0.02
@export var floor_snap: float = 2.0
@export var floor_angle_degrees: float = 46.0

@export_group("Hurtbox")
@export var small_hurt_height: float = 14.0
@export var small_crouch_hurt_height: float = 14.0
@export var super_hurt_height: float = 28.0
@export var crouch_hurt_height: float = 14.0
@export var stomp_tolerance: float = 4.0
@export var bounce_initial: float = -180.0
@export var bounce_held_initial: float = -360.0
@export var spin_bounce_initial: float = -120.0

@export_group("Presentation")
@export var animation_stride: float = 12.0
@export var spin_animation_fps: float = 18.0
@export var death_animation_fps: float = 4.0

@export_group("Experimental charge - never a speed or jump gate")
@export var p_meter_max: int = 112
@export var p_meter_charge_per_frame: int = 2
@export var p_meter_decay_per_frame: int = 1

@export_group("Power-up and death")
@export var powerup_freeze_frames: int = 44
@export var damage_freeze_frames: int = 36
@export var invulnerability_frames: int = 120
@export var flash_interval_frames: int = 4
@export var death_initial: float = -240.0
@export var death_gravity: float = 900.0
@export var death_delay_frames: int = 30
@export var death_duration_frames: int = 120

@export_group("Carry")
@export var hold_offset_small: Vector2 = Vector2(12.0, 8.0)
@export var hold_offset_super: Vector2 = Vector2(14.0, 0.0)
@export var throw_speed: float = 180.0
@export var throw_lift: float = -80.0
@export var throw_up_speed: float = -360.0

@export_group("Fire prototype")
@export var fireball_speed: float = 240.0
@export var fireball_gravity: float = 900.0
@export var fireball_bounce: float = -120.0
@export var fireball_radius: float = 3.0
@export var fireball_lifetime_frames: int = 180
@export var fireball_cooldown_frames: int = 12
@export var fireball_limit: int = 2


func is_full_speed(horizontal_speed: float) -> bool:
	return absf(horizontal_speed) >= run_max - speed_epsilon


func normal_jump_speed(horizontal_speed: float) -> float:
	if motion_model == MotionModel.SMMWE:
		if absf(horizontal_speed) > run_jump_threshold:
			return run_jump_initial
		return moving_jump_initial if absf(horizontal_speed) >= moving_jump_threshold else jump_initial
	var ratio: float = clampf((absf(horizontal_speed) - walk_max) / maxf(run_max - walk_max, speed_epsilon), 0.0, 1.0)
	return lerpf(jump_initial, run_jump_initial, ratio)


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if walk_max <= 0.0 or run_max <= walk_max:
		errors.append("run_max must exceed positive walk_max")
	if ground_accel <= 0.0 or skid_decel <= 0.0 or friction_normal <= 0.0 or air_accel_factor <= 0.0:
		errors.append("horizontal accelerations must be positive")
	if motion_model == MotionModel.SMMWE:
		if air_reverse_accel <= 0.0 or ground_overspeed_decel <= 0.0:
			errors.append("reference reverse and overspeed accelerations must be positive")
		if moving_jump_initial >= 0.0 or moving_jump_threshold < 0.0 or run_jump_threshold <= moving_jump_threshold or apex_gravity_threshold >= 0.0:
			errors.append("invalid reference jump tiers or apex threshold")
	if gravity_rise <= 0.0 or gravity_fall <= 0.0 or max_fall <= 0.0:
		errors.append("gravity and terminal speed must be positive")
	if jump_initial >= 0.0 or run_jump_initial >= 0.0 or spin_jump_initial >= 0.0:
		errors.append("jump velocities must be negative")
	if animation_stride <= 0.0 or speed_epsilon <= 0.0:
		errors.append("stride and speed epsilon must be positive")
	if hitbox_width <= 0.0 or small_height <= 0.0 or super_height < crouch_height or crouch_height <= 0.0:
		errors.append("invalid terrain shape sizes")
	if small_crouch_height <= 0.0 or small_crouch_height > small_height or super_height < small_height:
		errors.append("invalid standing/crouching height relationship")
	if small_hurt_height <= 0.0 or small_crouch_hurt_height <= 0.0 or super_hurt_height <= 0.0 or crouch_hurt_height <= 0.0:
		errors.append("hurtbox heights must be positive")
	if collision_margin < 0.0 or clearance_epsilon <= 0.0 or floor_snap < 0.0 or floor_angle_degrees <= 0.0 or floor_angle_degrees >= 90.0:
		errors.append("invalid collision query settings")
	if coyote_frames < 1 or jump_buffer_frames < 1 or flash_interval_frames < 1 or p_meter_max < 1:
		errors.append("frame windows must be positive")
	if powerup_freeze_frames < 0 or damage_freeze_frames < 0 or invulnerability_frames < 0:
		errors.append("power-up and invulnerability durations cannot be negative")
	if death_delay_frames < 1 or death_duration_frames <= death_delay_frames or death_initial >= 0.0 or death_gravity <= 0.0:
		errors.append("invalid death arc timing or velocities")
	if p_meter_charge_per_frame < 0 or p_meter_decay_per_frame < 0 or skid_threshold < 0.0:
		errors.append("charge rates and skid threshold cannot be negative")
	if spin_animation_fps < 0.0 or death_animation_fps < 0.0:
		errors.append("animation rates cannot be negative")
	if bounce_initial >= 0.0 or bounce_held_initial >= 0.0 or spin_bounce_initial >= 0.0:
		errors.append("bounce velocities must be negative")
	if fireball_speed <= 0.0 or fireball_gravity <= 0.0 or fireball_radius <= 0.0 or fireball_bounce >= 0.0:
		errors.append("invalid fireball trajectory")
	if fireball_limit < 1 or fireball_lifetime_frames < 1 or fireball_cooldown_frames < 0:
		errors.append("invalid fireball limit or timing")
	return errors
