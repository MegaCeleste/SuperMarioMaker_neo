class_name Player
extends CharacterBody2D

enum PowerForm { SMALL, SUPER }

@onready var state_machine: Node = $StateMachine
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var duck_shape: CollisionShape2D = $DuckShape
@onready var standing_shape: CollisionShape2D = $StandingShape
@onready var klock_sound: AudioStreamPlayer2D = $Sound/KlockSound
@onready var jump_sound: AudioStreamPlayer2D = $Sound/JumpSound
@onready var skid_sound: AudioStreamPlayer2D = $Sound/SkidSound
@onready var dead_sound: AudioStreamPlayer2D = $Sound/DeadSound
@onready var spin_jump_sound: AudioStreamPlayer2D = $Sound/SpinJumpSound
@onready var powerup_sound: AudioStreamPlayer2D = $Sound/PowerupSound

@export var super_sprite_frames: SpriteFrames

var small_sprite_frames: SpriteFrames
var power_form: PowerForm = PowerForm.SMALL

var ground_acceleration := 200.0
var max_walk_speed := 78.0
var max_run_speed := 180.0

var air_acceleration := 400.0
var max_fall_speed := 258.0

const JUMP_VELOCITY = -360.0
const SUPER_JUMP_VELOCITY = -430.0
const SPIN_JUMP_VELOCITY = -280.0
@export var GRAVITY = 900.0

# 在 Run 状态设置，Air 状态读取，用于超级跳跃动画
var is_priming_jump := false

func die() -> void:
	velocity = Vector2.ZERO
	state_machine.change_state(state_machine.dead)

func bounce() -> void:
	is_priming_jump = Input.is_action_pressed("player_jump")

	velocity.y = JUMP_VELOCITY * 1.0 if is_priming_jump else JUMP_VELOCITY * 0.6
	klock_sound.play()

	state_machine.change_state(state_machine.air)

func _ready() -> void:
	small_sprite_frames = animated_sprite.sprite_frames
	state_machine.init(self)

func set_form(form: PowerForm) -> void:
	if form == power_form:
		return
	power_form = form

	match form:
		PowerForm.SMALL:
			animated_sprite.sprite_frames = small_sprite_frames
			standing_shape.position = Vector2(0, 7.5)
			standing_shape.shape.size = Vector2(12, 15)
		PowerForm.SUPER:
			animated_sprite.sprite_frames = super_sprite_frames
			standing_shape.position = Vector2(0, 0)
			standing_shape.shape.size = Vector2(16, 30)
			powerup_sound.play()

	var current_anim = animated_sprite.animation
	if animated_sprite.sprite_frames.has_animation(current_anim):
		animated_sprite.play(current_anim)

func collect_mushroom() -> void:
	set_form(PowerForm.SUPER)

func _physics_process(delta: float)-> void:

	state_machine.process_physics(delta)
	_attempt_correction(delta, 2)

	# 统一处理重力（各状态不再重复写，Dead 悬空阶段通过 can_apply_gravity 跳过）
	if not is_on_floor() and state_machine.current_state.can_apply_gravity():
		velocity.y += GRAVITY * delta
		velocity.y = min(velocity.y, max_fall_speed)

	move_and_slide()

	if is_on_ceiling():
		for i in get_slide_collision_count():
			var col = get_slide_collision(i)
			var collider = col.get_collider() 
			if collider is InteractableBlock:
				if col.get_normal().y > 0.5:
					velocity.y = 10.0

					collider.hit_by_player(self)
					break

func _attempt_correction(delta: float, amount: int) -> void:
	if (
			velocity.y < 0
			and test_move(global_transform, Vector2(0, velocity.y * delta))
	):
		for i in range(1, amount * 2 + 1):
			for j in [-1.0, 1.0]:
				if not test_move(
						global_transform.translated(Vector2(i * j / 2, 0)),
						Vector2(0, velocity.y * delta)
				):
					translate(Vector2(i * j / 2, 0))
					if velocity.x * j / 2 < 0:
						velocity.x = 0
					return

	
