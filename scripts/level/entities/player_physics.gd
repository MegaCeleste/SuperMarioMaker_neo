# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerPhysics
extends Resource
## SMW overworld constants from obj_mario/Other_12.gml at 60Hz. Speeds
## multiply px/frame by 60; accelerations multiply px/frame² by 3600.

## Maximum ordinary walking speed, in pixels per second.
@export var walk_speed := 78.0
## Maximum ordinary running speed, in pixels per second.
@export var run_speed := 180.0
## Terminal downward speed for ordinary airborne movement, in pixels per second.
@export var fall_speed := 240.0
## Horizontal steering acceleration on ordinary ground, in pixels per second squared.
@export var acceleration := 216.0
## Passive horizontal braking on ordinary ground, in pixels per second squared.
@export var deceleration := 180.0
## Horizontal braking while reversing direction, in pixels per second squared.
@export var skid_deceleration := 468.0
## Braking above the current input's speed cap, in pixels per second squared.
@export var overspeed_deceleration := 90.0
## Steering acceleration on ice, in pixels per second squared.
@export var ice_acceleration := 180.0
## Reversal braking on ice, in pixels per second squared.
@export var ice_skid_deceleration := 108.0
## Passive braking on ice, in pixels per second squared.
@export var ice_deceleration := 18.0
## Crouched braking on ice, in pixels per second squared.
@export var ice_duck_deceleration := 36.0
## Upward launch speed for a low-speed jump, in pixels per second.
@export var idle_jump_speed := 237.0
## Upward launch speed for an intermediate-speed jump, in pixels per second.
@export var slow_jump_speed := 243.0
## Upward launch speed for a fast jump, in pixels per second.
@export var fast_jump_speed := 258.0
## Upward launch speed for an ordinary spin jump, in pixels per second.
@export var spin_jump_speed := 198.0
## Ordinary airborne downward acceleration, in pixels per second squared.
@export var gravity := 1080.0
## Reduced rising acceleration while Jump is held, in pixels per second squared.
@export var long_jump_gravity := 360.0
## Damage immunity duration in seconds after losing a powerup.
@export var damage_invulnerability := 2.0
## Initial death-pose hold duration, in seconds.
@export var death_hold_time := 30.0 / 60
## Delay between the death sequence and course retry, in seconds.
@export var death_retry_time := 120.0 / 60
## Upward launch speed for the death arc, in pixels per second.
@export var death_launch_speed := 210.0
## Downward acceleration during the death arc, in pixels per second squared.
@export var death_gravity := 720.0
## Terminal downward speed for the underwater death fall, in pixels per second.
@export var death_water_fall_speed := 120.0
