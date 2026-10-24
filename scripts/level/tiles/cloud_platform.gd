# SPDX-License-Identifier: AGPL-3.0-or-later
class_name CloudPlatform
extends StaticBodyExt
## obj_nube uses the5px-tall spr_square_b mask and solid-top policy.

var sub_area: SubArea


func _ready() -> void:
	collision_layer = 1
	z_index = 20
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(16, 5)
	shape.position = Vector2(8, 2.5)
	shape.one_way_collision = true
	shape.one_way_collision_margin = 0.5
	add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = CloudPart.texture_for(sub_area)
	sprite.centered = false
	add_child(sprite)


func crush() -> void:
	if is_queued_for_deletion():
		return
	EnemyEffect.play_once(sub_area, &"spr_smoke", global_position, 18)
	queue_free()
