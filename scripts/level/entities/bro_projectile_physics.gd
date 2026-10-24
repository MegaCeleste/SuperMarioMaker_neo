# SPDX-License-Identifier: AGPL-3.0-or-later
class_name BroProjectilePhysics
extends Resource
## SMW obj_brohammer/fireball_bro/snowball/boomerang motion in seconds.

@export var horizontal_speeds: PackedFloat32Array
@export var launch_speeds: PackedFloat32Array
@export var hammer_gravity: float
@export var water_hammer_gravity: float
@export var water_hammer_launch: float
@export var hammer_spin: float
@export var water_hammer_spin: float
@export var fall_cap: float
@export var molten_hammer_cap: float
@export var shot_gravity: float
@export var water_fire_gravity: float
@export var water_fire_cap: float
@export var ice_fall_cap: float
@export var fire_bounce: float
@export var ice_bounce: float
@export var boomerang_alarms: PackedInt32Array
@export var boomerang_turn: float
@export var boomerang_vertical_acceleration: float
@export var boomerang_spin: float
@export var boomerang_blink_time: float
@export var boomerang_expiry: float
@export var boomerang_blink_interval: float
