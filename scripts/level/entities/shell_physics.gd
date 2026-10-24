# SPDX-License-Identifier: AGPL-3.0-or-later
class_name ShellPhysics
extends Resource
## Speeds converted from obj_shell / obj_shell_held / obj_beachkoopa events.

@export var kick_idle_speed: float
@export var kick_idle_target: float
@export var kick_base_speed: float
@export var release_base_speed: float
@export var target_limit: float
@export var acceleration: float
@export var enemy_gravity: float
@export var idle_shell_gravity: float
@export var fall_speed: float
@export var throw_horizontal_speed: float
@export var throw_up_speed: float
@export var dropped_speed: float
@export var launch_immunity: float
@export var eject_speed: float
@export var eject_deceleration: float
@export var eject_invulnerability: float
@export var beach_wait: float
@export var beach_hop: float
@export var reentry_hop: float
@export var combo_scores: PackedInt32Array
