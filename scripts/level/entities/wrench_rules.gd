# SPDX-License-Identifier: AGPL-3.0-or-later
class_name WrenchRules
extends EnemyDefeatStyle
## obj_wrench's SMW animation, arc, source alarms and view margin.

@export var flight_sprite: StringName
@export var flight_fps := 12.0
@export var speed := 60.0
@export var water_speed := 30.0
@export var arc_heights := PackedFloat32Array([0, 5, 13, 21, 29])
@export var arc_acceleration := 180.0
@export var arc_speed := 30.0
@export var blink_time := 6.0
@export var blink_interval := 7.0 / 60
@export var lifetime := 8.0
@export var view_margin := 128.0
