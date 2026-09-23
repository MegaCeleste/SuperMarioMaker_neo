class_name Enemy
extends CharacterBody2D

var dir =  -1
var speed = 40.0
var is_dead = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var physics_shape: CollisionShape2D = $PhysicsShape
@onready var stomp_area: Area2D = $StompArea
@onready var hurt_area: Area2D = $HurtArea

func _ready() -> void:
	sprite.play("idle")
	stomp_area.body_entered.connect(_on_stomp_area_entered)
	hurt_area.body_entered.connect(_on_hurt_area_entered)


func _physics_process(delta: float) -> void:
	sprite.flip_h = dir < 0

	if not is_on_floor():
		velocity.y += 900 * delta
	else:
		velocity.x = dir * speed

	if is_dead:
		if is_on_floor():
			velocity.x = 0
			#===await get_tree().create_timer(10).timeout
			#===is_dead = false
			#===sprite.flip_v = false==== 复活
			
		move_and_slide()
		if global_position.y > 1000:
			queue_free()
		return



	move_and_slide()
	
	if is_on_wall():
		dir *= -1


func _on_stomp_area_entered(body: Node2D) -> void:
	if is_dead:
		return

	if body is Player:
		if body.velocity.y >= 0:
			body.bounce()
			add_collision_exception_with(body)
			die()

func _on_hurt_area_entered(body: Node2D) -> void:
	if is_dead:
		return
	if body is Player:
		print("受伤了")
		body.die()

func die() -> void:
	stomp_area.set_deferred("monitoring", false)
	hurt_area.set_deferred("monitoring", false)

	is_dead = true
	sprite.flip_v = true
	velocity.y = -200
	velocity.x = 0

	# 平滑旋转动画
	var tween = create_tween()
	sprite.rotation_degrees = 0
	tween.tween_property(sprite, "rotation_degrees", 360, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
