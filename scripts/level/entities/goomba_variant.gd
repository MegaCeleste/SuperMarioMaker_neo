# SPDX-License-Identifier: AGPL-3.0-or-later
class_name GoombaVariant
extends Resource
## SMW resource identity and runtime differences for Galoomba / Goombud.

@export var id: StringName
@export var object_id: String
@export var label: StringName
@export var icon: Texture2D
@export var walk_sprite: StringName
@export var held_sprite: StringName
@export var dead_sprite: StringName
@export var flight: EnemyFlightProfile
@export var avoid_ledges := false
@export var recovery_time := 10.0
@export var shake_time := 9.0
@export var recovery_hop_speed := 60.0
