# SPDX-License-Identifier: AGPL-3.0-or-later
class_name GrrrolVariant
extends ThwompVariant
## The rolling branch shares the source Thwomp editor tool, not its attack AI.

@export var legacy := false
@export var editor_draw_center := Vector2(16, 16)
@export var runtime_mask := Rect2(-18, -38, 36, 38)
@export var walk_speed := 72.0
@export var water_walk_speed := 60.0
@export var left_acceleration := 80.64
@export var right_acceleration := 116.64
@export var drag := 288.0
## Source air rightward overspeed branch starts only above 2px/frame.
@export var right_drag_threshold := 120.0
@export var rotation_speed := 210.0
@export var wall_hop := 60.0
@export var block_probe := 3.0
@export var side_inset := 4.0
@export var transform_sprite: StringName = &"spr_effect_transform"


func source_mask() -> Rect2:
	return Rect2(runtime_mask.position + source_to_feet, runtime_mask.size)
