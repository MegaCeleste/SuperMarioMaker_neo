# SPDX-License-Identifier: AGPL-3.0-or-later
class_name EnemyPartPreview
extends RefCounted
## Align only static art to its native placement footprint. Call after restoring
## the authored sprite/attachment positions, so refresh never accumulates shifts.
## Graphics' drag rotation/scale is intentionally outside this resting basis.


static func align_contact(part: Part, sprite: Sprite2D, orientation := 0,
		decoration: Node2D = null) -> void:
	if sprite.texture == null:
		return
	var used := Rect2(sprite.texture.get_image().get_used_rect())
	if not used.has_area():
		return
	var size := sprite.texture.get_size()
	if sprite.flip_h:
		used.position.x = size.x - used.end.x
	if sprite.flip_v:
		used.position.y = size.y - used.end.y
	used.position += sprite.get_rect().position
	var art := sprite.transform * used
	art.position += (sprite.get_parent() as Node2D).position
	var collider: CollisionShape2D = part.get_node("CollShape")
	var placement := collider.transform * collider.shape.get_rect()
	var shift := Vector2.ZERO
	match orientation:
		1: shift.y = placement.position.y - 1 - art.position.y
		2: shift.x = placement.position.x - 1 - art.position.x
		3: shift.x = placement.end.x + 1 - art.end.x
		_: shift.y = placement.end.y + 1 - art.end.y
	sprite.position += shift
	if decoration != null:
		decoration.position += shift
