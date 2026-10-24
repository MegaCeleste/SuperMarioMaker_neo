# SPDX-License-Identifier: AGPL-3.0-or-later
class_name SinkingEnemy
extends Node2D
## obj_enemyparent_lava's slow sink keeps its own sprite and optional spin recoil.

var sub_area: SubArea
var sprite_name: StringName
var mask_size := Vector2(10, 16)
var mask_center := Vector2(0, 8)
var ellipse_mask := true
var initial_frame := 0
var animate := true
var direction := 1.0
var velocity := 0.0
var _age := 0.0
var _sprite: AnimatedSprite2D
var _area: Area2D


func _ready() -> void:
	z_index = GameConstants.Layers.Z_ENTITIES
	_sprite = SpriteLibrary.make_sprite(sprite_name)
	_sprite.sprite_frames = SpriteLibrary.get_animations({"sink": [String(sprite_name), 9, true]})
	_sprite.play(&"sink")
	_sprite.pause()
	_sprite.frame = initial_frame
	_sprite.flip_h = direction < 0
	add_child(_sprite)
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 4
	if ellipse_mask:
		SpriteCollision.add_shapes(_area, [SpriteCollision.ellipse(mask_size, mask_center)])
	else:
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = mask_size
		collider.shape = shape
		collider.position = mask_center
		_area.add_child(collider)
	add_child(_area)


func _physics_process(delta: float) -> void:
	_age += delta
	if animate and _age >= 2.0 / 60:
		_sprite.play(&"sink")
	velocity = minf(1.8, velocity) + 108 * delta
	position.y += velocity * delta
	var liquid := sub_area.liquid
	if is_instance_valid(liquid) and liquid.velocity > 0 and global_position.y <= liquid.global_position.y + 16:
		global_position.y = liquid.global_position.y + 16
	for body in _area.get_overlapping_bodies():
		if body is Player and not body.is_dead() and body.velocity.y >= 0 \
				and body.state_machine.current_state is PlayerSpinJumpingState \
				and body.previous_position.y < global_position.y + mask_center.y - mask_size.y / 2 - velocity * delta + 6:
			body.bounce()
	if position.y >= 16 or (velocity > 0 and is_instance_valid(liquid) and global_position.y > liquid.global_position.y + 32):
		queue_free()
