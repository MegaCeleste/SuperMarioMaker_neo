# SPDX-License-Identifier: AGPL-3.0-or-later
class_name HiddenBlock
extends Area2D
## Invisible and nonblocking until an upward head/shell crossing reveals it.

var sub_area: SubArea
var sprout: Sprout
var revealed := false


func _ready() -> void:
	process_physics_priority = -10
	collision_layer = 0
	collision_mask = 4 | 2 | 8
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(32, 80)
	shape.position = Vector2(8, 40)
	add_child(shape)


func _physics_process(delta: float) -> void:
	if revealed or sub_area.level.status != Level.Status.PLAYING:
		return
	var bottom := global_position.y + 16
	for body in get_overlapping_bodies():
		if not (body is Player or body is KoopaShell):
			continue
		if body is Player and (body.is_dead() or body.is_frozen()):
			continue
		if body.velocity.y >= 0:
			continue
		var bounds := Utility.get_bounding_box(body)
		var next: Vector2 = bounds.position + body.velocity * delta
		if bounds.position.y >= bottom - 0.1 and next.y <= bottom + 1 \
				and next.x < global_position.x + 16 and next.x + bounds.size.x > global_position.x:
			reveal(body)
			return


func reveal(activator: PhysicsBody2D) -> QuestionBlock:
	if revealed:
		return null
	revealed = true
	var tile: QuestionBlock = preload("res://scenes/tiles/question_block.tscn").instantiate()
	tile.position = position
	tile.get_node("%BlockComponent").sprout = sprout
	sub_area.add(tile)
	tile.show_used_art()
	tile.get_node("%BlockComponent").activate(activator)
	queue_free()
	return tile
