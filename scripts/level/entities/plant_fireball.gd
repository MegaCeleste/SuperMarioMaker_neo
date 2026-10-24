# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlantFireball
extends Entity
## obj_plantfire: diagonal shot, terrain burst, player hit and camera culling.

var variant: PiranhaVariant
var _shapes: Array[ConvexPolygonShape2D]


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var sprite := SpriteLibrary.make_sprite(variant.projectile_sprite)
	sprite.sprite_frames = SpriteLibrary.get_animations({"fire": [String(variant.projectile_sprite), 9, true]})
	sprite.play(&"fire")
	add_child(sprite)
	_shapes = SpriteCollision.precise(variant.projectile_sprite)
	SpriteCollision.add_shapes(self, _shapes)
	var area := Area2D.new()
	area.name = "PlayerArea"
	area.collision_layer = 0
	area.collision_mask = 4
	SpriteCollision.add_shapes(area, _shapes)
	area.body_entered.connect(func(body):
		if body is Player and not is_queued_for_deletion():
			body.damage()
			queue_free())
	add_child(area)


func _physics_process(delta: float) -> void:
	if move_and_collide(velocity * delta) != null:
		_burst()
		return
	# Source semisolids burst shots approaching from below as well as above.
	var query := PhysicsShapeQueryParameters2D.new()
	query.collision_mask = 1
	query.transform = global_transform
	for shape in _shapes:
		query.shape = shape
		if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			_burst()
			return
	var transform := get_viewport_transform()
	var screen := transform * global_position
	if not get_viewport_rect().grow(32 * transform.get_scale().x).has_point(screen):
		queue_free()


func _burst() -> void:
	if is_queued_for_deletion():
		return
	EnemyEffect.play_once(sub_area, variant.smoke_sprite, global_position + Vector2(-8, 0), 18)
	EnemyEffect.sound_once(sub_area, variant.impact_sound)
	queue_free()
