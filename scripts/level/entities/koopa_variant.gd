# SPDX-License-Identifier: AGPL-3.0-or-later
class_name KoopaVariant
extends ShellVariant

@export var object_id: String
@export var label: StringName
@export var icon: Texture2D
@export var walk_sprite: StringName
@export var beach_sprite: StringName
@export var beach_walk_sprite: StringName
@export var beach_crawl_dead_sprite: StringName
@export var beach_walk_dead_sprite: StringName
@export var beach_stomp_sprite: StringName
@export var flight: EnemyFlightProfile
@export var avoid_ledges := false
@export var walk_fps := 6.0
