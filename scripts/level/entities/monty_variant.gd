# SPDX-License-Identifier: AGPL-3.0-or-later
class_name MontyVariant
extends EnemyDefeatStyle
## Source obj_monty_res editor anchor and obj_monty_chase constants.

@export var id: StringName = &"monty"
@export var object_id := "obj_monty_res"
@export var label: StringName = &"EDITOR_ENEMY_MONTY"
@export var walk_sprite: StringName = &"spr_montymole"
@export var editor_sprite: StringName = &"spr_monty_res"
@export var editor_frame := 2
@export var editor_origin := Vector2(5, 6)
@export var mask_size := Vector2(10, 16)
@export var walk_speed := 90.0
## Source Step_0 deliberately caps leftward water chasing at 1px/frame;
## rightward chasing still caps at 1.5. The 0.6 value is wall recoil only.
@export var water_left_speed := 60.0
@export var water_wall_speed := 36.0
@export var acceleration := 116.64
@export var wall_hop := 90.0
@export var walk_fps := 12.0
@export var flight: EnemyFlightProfile = preload("res://resources/content/smw_flight_monty.tres")
