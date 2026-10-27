# SPDX-License-Identifier: AGPL-3.0-or-later
class_name BlockBreakRequest
extends Node
## A block-owned source alarm2, independent of the actor that armed it.

var sub_area: SubArea
var shard_sprite: StringName
var empty_sprite: StringName
var stronger := false
var _created_tick: int


static func arm(area: SubArea, body: PhysicsBody2D, art: StringName, empty: StringName, strong := false) -> void:
	if body.is_queued_for_deletion() or body.has_node("SourceBreakAlarm"):
		return
	var alarm := BlockBreakRequest.new()
	alarm.name = "SourceBreakAlarm"
	alarm.sub_area = area
	alarm.shard_sprite = art
	alarm.empty_sprite = empty
	alarm.stronger = strong
	alarm._created_tick = Engine.get_physics_frames()
	alarm.process_physics_priority = -30
	body.add_child(alarm)


func _physics_process(_delta: float) -> void:
	if Engine.get_physics_frames() <= _created_tick:
		return
	var body := get_parent() as PhysicsBody2D
	if not body.is_queued_for_deletion():
		_bump_above(body)
		break_now(sub_area, body, shard_sprite, empty_sprite, stronger)


func _bump_above(body: PhysicsBody2D) -> void:
	var bounds := Utility.get_bounding_box(body)
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(bounds.size.x, 2)
	query.shape = shape
	query.transform.origin = Vector2(bounds.get_center().x, bounds.position.y - 1)
	query.collision_mask = 2
	for hit in body.get_world_2d().direct_space_state.intersect_shape(query, 16):
		var enemy := hit.collider as Enemy
		if enemy == null or enemy.hardness >= 99 or enemy is Rocky or enemy.is_queued_for_deletion():
			continue
		enemy.bumped_by_block(body, body)


static func break_now(area: SubArea, body: PhysicsBody2D, art: StringName, empty: StringName, stronger := false) -> void:
	if body.is_queued_for_deletion():
		return
	var point := Utility.get_bounding_box(body).position
	var block: BlockComponent = Utility.find_child_by_class(body, BlockComponent)
	var sprite := empty if not stronger and body is QuestionBlock and not block.enabled else art
	var offsets := [Vector2(4, 4), Vector2(4, 12), Vector2(12, 12), Vector2(12, 4)]
	var angles := [45.0, 60.0, 120.0, 135.0]
	for index in 4:
		var shard := BlockShard.new()
		shard.sub_area = area
		shard.sprite_name = sprite
		shard.position = area.get_foreground().to_local(point + offsets[index])
		shard.velocity = Vector2.from_angle(-deg_to_rad(angles[index])) * (360 if stronger else 300)
		shard.spin_direction = 1 if index < 2 else -1
		area.add_deferred(shard)
	EnemyEffect.sound_once(area, SoundLibrary.path("snd_break"))
	body.collision_layer = 0
	body.collision_mask = 0
	body.queue_free()
