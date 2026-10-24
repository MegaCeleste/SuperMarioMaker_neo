# SPDX-License-Identifier: AGPL-3.0-or-later
class_name ChompVariant
extends EnemyDefeatStyle
## obj_chain_chomp_free[_b]: a free head with four history-following links.

@export var id: StringName = &"small"
@export var object_id := "obj_chomp_res"
@export var label: StringName = &"EDITOR_ENEMY_CHAIN_CHOMP"
@export var head_sprite: StringName = &"spr_chainchomp"
@export var chain_sprite: StringName = &"spr_chain"
@export var editor_sprite: StringName = &"spr_chainchomp_res"
@export var dark_editor_sprite: StringName = &"spr_chainchomp_night_res"
@export var editor_origin := Vector2(0, 1)
@export var canvas_size := Vector2(16, 16)
## Bounds relative to native feet; source masks are ellipses, not full squares.
@export var mask_rect := Rect2(-5, -13, 10, 13)
@export var source_to_feet := 8.0
@export var history_length := 40
@export var link_spacing := 7
@export var hop_speed := 120.0
@export var water_hop_speed := 90.0
@export var launch_speed := 78.0
@export var water_launch_speed := 48.0
@export var walk_speed := 60.0
@export var water_walk_speed := 30.0
@export var deceleration := 288.0
@export var gravity := 450.0
@export var fall_speed := 240.0
@export var water_fall_speed := 60.0
@export var wake_delay := 2.0 / 60
@export var head_fps := 9.0
@export var decoration: EnemyFlightProfile


func part_to_feet() -> Vector2:
	return Vector2(canvas_size.x / 2, canvas_size.y)


func source_mask() -> Rect2:
	return Rect2(mask_rect.position + Vector2(0, source_to_feet), mask_rect.size)
