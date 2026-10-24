# SPDX-License-Identifier: AGPL-3.0-or-later
class_name BuzzyVariant
extends ShellVariant

@export var object_id: String
@export var label: StringName
@export var icon: Texture2D
@export var walk_sprite: StringName
@export var editor_sprite: StringName
@export var winged_editor_sprite: StringName
@export var flight: EnemyFlightProfile
@export var empty_shell := false
@export var walk_fps := 9.0
