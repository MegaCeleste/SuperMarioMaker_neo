# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerAnimationRules
extends Resource
## obj_mario/Step_2: image_speed = min(abs(hspeed / 5), .3) at 60 Hz.

## Source horizontal pixels per tick corresponding to one animation frame per tick.
@export var pixels_per_frame := 5.0
## Maximum walking/running animation playback rate, in frames per second.
@export var max_locomotion_fps := 18.0
## Dust starts at a brisk walk, independently of the full-run skid pose.
@export var skid_dust_min_speed := 60.0
## Delay between ordinary walking-brake clouds, in seconds.
@export var skid_dust_interval := 8.0 / 60
## Delay between running-brake clouds; each cloud stays at its emission position.
@export var running_skid_dust_interval := 5.0 / 60
## Lifetime of one running-brake cloud, in seconds.
@export var running_skid_dust_lifetime := 0.18
