# SPDX-License-Identifier: AGPL-3.0-or-later
class_name GoalPolePart
extends Part
## Goal placement. SMW uses the two-post gate from obj_goalgate; its origin
## is the top of the 137px post, not a snapped terrain position.


static func create() -> GoalPolePart:
	return load("res://scenes/level/parts/goal_pole_part.tscn").instantiate()


func can_erase() -> bool:
	return false


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	if SpriteLibrary.has_sprite(&"spr_goalgate"):
		var post := SpriteLibrary.make_sprite(&"spr_goalgate")
		post.position = Vector2(-8, -8)
		%Graphics.add_child(post)


func build() -> void:
	var gate := preload("res://scenes/level/tiles/goal_gate.tscn").instantiate()
	gate.level = level
	gate.position = position
	sub_area.add(gate)
