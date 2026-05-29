class_name Player
extends CharacterBody2D
@onready var ray_cast_2d: RayCast2D = $RayCast2D
@onready var state_machine: Node = $StateMachine
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var duck_shape: CollisionShape2D = $DuckShape
@onready var standing_shape: CollisionShape2D = $StandingShape
@onready var skid_sound: AudioStreamPlayer2D = $SkidSound
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound
@onready var klock_sound: AudioStreamPlayer2D = $KlockSound
@onready var dead_sound: AudioStreamPlayer2D = $DeadSound

var ground_acceleration := 200.0
var max_walk_speed := 78.0
var max_run_speed := 180.0

var air_acceleration := 400.0
var max_fall_speed := 258.0

const JUMP_VELOCITY = -360.0
const SUPER_JUMP_VELOCITY = -430.0
@export var GRAVITY = 900.0

var is_ducking := false
var is_priming_jump := false
var is_skidding := false
var skid_timer := 0.0
var skid_charge_time := 0.0
const skid_threshold := 0.05

func die() -> void:
	velocity = Vector2.ZERO
	state_machine.change_state($"StateMachine/Dead")

func bounce() -> void:
	is_priming_jump = Input.is_action_pressed("player_jump")

	velocity.y = JUMP_VELOCITY * 1.0 if is_priming_jump else JUMP_VELOCITY * 0.6
	klock_sound.play()

	state_machine.change_state($"StateMachine/Air")

func _ready() -> void:
	state_machine.init(self)

func _physics_process(delta: float)-> void:
	state_machine.process_physics(delta)
	move_and_slide()

	if is_on_ceiling():
		print("1.马里奥撞到了天花板")
		for i in get_slide_collision_count():
			var col = get_slide_collision(i)
			var collider = col.get_collider() 
			if collider is InteractableBlock:
				if col.get_normal().y > 0.5:
					print("2.确认撞到方块顶部，准备调用父类")
					velocity.y = 10.0

					collider.hit_by_player(self)
					break
