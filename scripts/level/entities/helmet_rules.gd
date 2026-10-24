# SPDX-License-Identifier: AGPL-3.0-or-later
class_name HelmetRules
extends Resource

@export var id: StringName = &"buzzy"
@export var goal_animation: StringName = &"goal_buzzy"
@export var defeat_on_head := false
@export var equip_sound := "snd_helmet_add.ogg"
@export var deflect_sound := "snd_helmet.ogg"
@export var remove_sound := "snd_helmet_remove.ogg"
@export var head_size := Vector2(20, 17)
@export var head_center := Vector2(0, 0.5)
@export var head_top := -8.0
@export var head_ellipse := false
@export var head_up_size := Vector2(20, 17)
@export var head_up_center := Vector2(0, 1.5)
@export var shell_deflect_speed := 60.0
@export var equip_sprite: StringName
@export var equip_offset := Vector2.ZERO
@export var normal_sprite: StringName
@export var up_sprite: StringName
@export var spark_sprite: StringName
@export var small_y: float
@export var super_y: float
@export var small_up_y: float
@export var super_up_y: float
@export var super_duck_y := 20.0
@export var super_hold_duck_y := 16.0
@export var small_duck_y := 21.0
@export var small_hold_duck_y := 19.0
@export var head_bounce_speed: float
@export var rising_bounce_extra: float
@export var physical_rising_bounce_extra := 60.0
@export var walking_angle: float
@export var falling_angle: float
@export var falling_rotation_speed: float
