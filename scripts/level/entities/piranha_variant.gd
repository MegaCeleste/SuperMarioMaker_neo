# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PiranhaVariant
extends EnemyDefeatStyle
## Independent SMW jumping/fire resource identities, art and source timings.

@export var id: StringName
@export var object_id: String
@export var label: StringName
@export var icon: Texture2D
@export var fire := false
@export var editor_sprite: StringName
@export var idle_sprite: StringName
@export var jump_sprite: StringName
@export var aim_up_sprite: StringName
@export var projectile_sprite: StringName
@export var smoke_sprite: StringName
@export var lava_splash_sprite: StringName
@export var poison_splash_sprite: StringName
@export var flight: EnemyFlightProfile
@export var mask_size := Vector2(10, 16)
@export var mask_center := Vector2(0, -8)
@export var editor_size := Vector2(18, 24)
@export var editor_origin := Vector2(1, 8)
@export var idle_fps := 33.0
@export var jump_fps := 9.0
@export var gravity := 108.0
@export var water_gravity := 72.0
@export var fall_speed := 30.0
@export var water_fall_speed := 18.0
@export var jump_speed := 150.0
@export var water_jump_speed := 120.0
@export var jump_wait := 3.0
@export var float_gravity := 360.0
@export var float_fall_speed := 24.0
@export var horizontal_drag := 540.0
@export var sway_speed := 30.0
@export var water_sway_speed := 18.0
@export var sway_acceleration := 54.0
@export var sway_distance := 16.0
@export var initial_attack := 2.0
@export var attack_wait := 100.0 / 60
@export var attack_windup := 0.5
@export var attack_recovery := 40.0 / 60
@export var projectile_speed := Vector2(60, 30)
@export var water_projectile_speed := Vector2(30, 15)
@export var shot_sound := "res://assets/openwe/sounds/snd_podoboo.ogg"
@export var impact_sound := "res://assets/openwe/sounds/snd_bump.ogg"
