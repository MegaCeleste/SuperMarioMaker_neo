# SPDX-License-Identifier: AGPL-3.0-or-later
class_name ThwompVariant
extends Resource
## Source editor origins, native feet conversion and SMW attack constants.

@export var id: StringName = &"thwomp"
@export var object_id := "obj_thwomp_res"
@export var label: StringName = &"EDITOR_ENEMY_THWOMP"
@export var body_sprite: StringName = &"spr_thwomp"
@export var horizontal_sprite: StringName = &"spr_thwomp_h"
## The small object's explicit mask stays vertical; giant uses its sprite.
@export var mask_sprite: StringName = &"spr_thwomp"
@export var editor_sprite: StringName = &"spr_SMW_thwomp_res"
@export var arrow_sprite: StringName = &"spr_button_change_thwomp"
@export var alternate_editor_sprite: StringName = &"spr_grrrol_old"
@export var break_sprite: StringName = &"spr_shard"
@export var empty_break_sprite: StringName = &"spr_shard_th"
@export var giant := false
@export var mask_size := Vector2(24, 32)
@export var source_to_feet := Vector2(0, 16)
@export var part_to_feet := Vector2(16, 32)
@export var editor_bounds := Rect2(0, 0, 32, 32)
@export var arrow_center := Vector2(16, 16)
@export var arrow_button := Rect2(7, 7, 18, 18)
@export var gravity := 720.0
@export var water_gravity := 90.0
@export var fall_speed := 240.0
@export var water_fall_speed := 30.0
@export var parachute_gravity := 360.0
@export var parachute_fall_speed := 24.0
@export var side_acceleration := 180.0
@export var side_speed := 180.0
@export var water_side_speed := 90.0
@export var return_speed := 60.0
@export var return_snap_distance := 1.0
## Alarm_1's local sprite_l shadows the instance's unchanged default.
@export var splash_sprite: StringName = &"spr_SMB3_megasplash_lava"
@export var splash_fps := 18.0
@export var splash_first_tick := 1.0 / 60
@export var splash_interval := 12.0 / 60
@export var impact_wait := 1.0
@export var vertical_trigger_margin := 32.0
@export var vertical_trigger_offset := 17.0
@export var side_trigger_distance := 112.0
@export var side_trigger_inset := 4.0
@export var side_trigger_top := 40.0
@export var side_trigger_bottom := 7.0
@export var impact_sound := "snd_thwomp_original"


func source_position(feet: Vector2) -> Vector2:
	return feet - source_to_feet
