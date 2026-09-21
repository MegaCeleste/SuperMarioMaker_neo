class_name entities
extends CharacterBody2D

@onready var pickup_area: Area2D = $PickupArea
@onready var 蘑菇物理碰撞箱: CollisionShape2D = $CollisionShape2D


var speed = 60.0
var gravity = 900
var dir = -1

func _ready() -> void:
	pickup_area.body_entered.connect(_on_pickup_area_body_entered)


func _on_pickup_area_body_entered(body: Node) -> void:
	if body is Player:
		body.collect_mushroom()
		queue_free()


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
