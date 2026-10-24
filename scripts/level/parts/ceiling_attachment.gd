# SPDX-License-Identifier: AGPL-3.0-or-later
class_name CeilingAttachment
extends RefCounted
## Resource attachment uses the complete native Part topology, not a new atlas.


static func is_attached(part: Part) -> bool:
	return orientation(part) == 1


## Floor support takes priority, followed by ceiling, left wall and right wall.
static func orientation(part: Part) -> int:
	if part.sub_area == null:
		return 0
	var above := false
	var below := false
	var left := false
	var right := false
	for neighbor in part.sub_area.get_parts().get_children():
		if neighbor is GroundPart or neighbor is QuestionBlockPart or neighbor is TurnBlockPart:
			above = above or neighbor.position == part.position + Vector2(0, -16)
			below = below or neighbor.position == part.position + Vector2(0, 16)
			left = left or neighbor.position == part.position + Vector2(-16, 0)
			right = right or neighbor.position == part.position + Vector2(16, 0)
	return 0 if below else 1 if above else 2 if left else 3 if right else 0
