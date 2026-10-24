# SPDX-License-Identifier: AGPL-3.0-or-later
class_name SpikeTile
extends StaticBodyExt
## Source obj_pinchos: a14x16 rectangular solid, not a stompable enemy.

var sub_area: SubArea
var _sprite: AnimatedSprite2D


func _ready() -> void:
	collision_layer = 1
	z_index = 20
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(14, 16)
	shape.position = Vector2(8, 8)
	add_child(shape)
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.sprite_frames = SpriteLibrary.get_frames(SpikePart.sprite_for(sub_area))
	_sprite.centered = false
	add_child(_sprite)
	_physics_process(0)
	collided.connect(_contact)


func _physics_process(_delta: float) -> void:
	# obj_pinchos/Draw uses levelmanager.banim3 +=0.1/tick, not the
	# sprite resource's60fps default. All spikes share the same phase.
	_sprite.frame = int(floor(sub_area.level.animation_time * 6 + 0.00001)) \
			% _sprite.sprite_frames.get_frame_count(&"default")


func _contact(hit: KinematicCollision2D) -> void:
	var actor: Node = hit.get_local_shape().get_parent()
	if not actor is Player:
		return
	# Source head probes skip spike damage when a helmet covers the head.
	# Side/foot contacts still use normal damage, armor and star immunity.
	if hit.get_normal().y > 0.5 and actor.has_helmet():
		return
	actor.damage()
