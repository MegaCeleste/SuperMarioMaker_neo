# SPDX-License-Identifier: AGPL-3.0-or-later
class_name SpinyVariant
extends ShellVariant
## Editor/resource identity and SMW walking/winged Spiny behavior.

@export var object_id: String
@export var label: StringName
@export var icon: Texture2D
@export var walk_sprite: StringName
@export var editor_sprite: StringName
@export var winged_editor_sprite: StringName
@export var flight: EnemyFlightProfile
@export var empty_shell := false
@export var walk_fps := 7.5
@export var ball_sprite: StringName
@export var needle_sprite: StringName
@export var attack_wait := 2.1
@export var attack_windup := 1.0
@export var attack_recover := 0.5
@export var needle_speed := 42.0
@export var needle_blink_time := 6.0
@export var needle_lifetime := 8.0
