# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PowCoin
extends Area2D
## A coin a POW knocked loose (source obj_coin_pow): it falls, settles on
## solid ground and can be collected like an ordinary coin.

const GRAVITY := 540.0
const MAX_FALL := 240.0
const FRICTION := 120.0

var velocity := Vector2.ZERO
var _collected := false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 4  # The player layer, as for ordinary coins.
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(12, 14)
	shape.position = Vector2(8, 8)
	add_child(shape)
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	add_child(sprite)
	# Same art and 9fps spin as an ordinary Coin.
	SpriteLibrary.configure_sprite(sprite, &"spr_coin", &"default", 9)
	body_entered.connect(_body_entered)


func _physics_process(delta: float) -> void:
	velocity.y = minf(MAX_FALL, velocity.y + GRAVITY * delta)
	var next := position + velocity * delta
	# Land on the first solid below the coin's bottom centre.
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(8, 15),
			global_position + Vector2(8, 16) + Vector2(0, velocity.y * delta + 1), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if velocity.y > 0 and not hit.is_empty():
		next.y = get_parent().to_local(hit.position).y - 16
		velocity.y = 0
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
	position = next
	if global_position.y > Player.VOID_LEVEL:
		queue_free()


func _body_entered(body: Node2D) -> void:
	if body is Player and not _collected and not body.is_dead():
		_collected = true
		body.collect_coin()
		queue_free()
