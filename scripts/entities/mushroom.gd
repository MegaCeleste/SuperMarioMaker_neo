class_name entities
extends CharacterBody2D

var speed = 60.0
var gravity = 900
var dir = -1

func _ready() -> void:
	pass


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.x = dir * speed

	if global_position.y > 1000:
		queue_free()

	move_and_slide()
	if is_on_wall():
		dir *= -1
