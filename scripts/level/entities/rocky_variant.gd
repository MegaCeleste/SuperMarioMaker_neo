# SPDX-License-Identifier: AGPL-3.0-or-later
class_name RockyVariant
extends EnemyDefeatStyle
## Source obj_rocky_res anchor and obj_rocky/obj_wrench constants.

@export var id: StringName = &"rocky"
@export var object_id := "obj_rocky_res"
@export var label: StringName = &"EDITOR_ENEMY_ROCKY"
@export var idle_sprite: StringName = &"spr_rocky_idle"
@export var idle2_sprite: StringName = &"spr_rocky_idle2"
@export var throw_sprite: StringName = &"spr_rocky_throw"
@export var editor_sprite: StringName = &"spr_rocky_res"
@export var wrench_rules: WrenchRules = preload("res://resources/content/smw_wrench_rules.tres")
@export var editor_frame := 2
@export var editor_origin := Vector2(1, 4)
@export var mask_size := Vector2(14, 16)
@export var pop_speed := 90.0
@export var water_pop_speed := 48.0
@export var rise_speed := 30.0
@export var gravity := 720.0
@export var water_gravity := 72.0
@export var fall_speed := 240.0
@export var water_fall_speed := 60.0
@export var wait_ticks := 60
@export var retry_ticks := 10
@export var high_wait_ticks := 90
@export var windup_ticks := 2
@export var throw_ticks := 30
@export var idle_ticks := 30
