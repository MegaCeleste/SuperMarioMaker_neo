# SPDX-License-Identifier: AGPL-3.0-or-later
class_name BlooperRules
extends Resource
## obj_blooper: native velocity/time units and source art/mask geometry.

@export var swim_sprite: StringName
@export var editor_sprite: StringName
@export var defeat_sprite: StringName
@export var editor_decorations: EnemyFlightProfile
@export var jet_speed := 90.0
@export var jet_time := 40.0 / 60
@export var cooldown_time := 40.0 / 60
@export var sink_gravity := 180.0
@export var sink_speed := 30.0
@export var mask_size := Vector2(10, 18)
@export var mask_center := Vector2(0, -9)
@export var defeat_fps := 3.0
@export var defeat_offset := Vector2(0, -8)
@export var defeat_air_launch := -6.0
@export var defeat_water_launch := -2.4
@export var defeat_air_rise_gravity := 720.0
@export var defeat_air_fall_gravity := 360.0
@export var defeat_water_gravity := 72.0
@export var defeat_fall_speed := 60.0
