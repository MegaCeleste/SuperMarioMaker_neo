# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerSwimRules
extends Resource
## obj_mario/Other13 at60Hz; source speeds*60, accelerations*3600.

## Horizontal steering acceleration in pixels per second squared.
@export var acceleration := 180.0
## Maximum horizontal speed away from the underwater floor, in pixels per second.
@export var speed := 60.0
## Horizontal speed cap while supported by the underwater floor, in pixels per second.
@export var floor_speed := 30.0
## Downward acceleration during swimming, in pixels per second squared.
@export var gravity := 108.0
## Maximum downward swimming speed, in pixels per second.
@export var sink_speed := 60.0
## Steady upward speed cap before a stroke is applied, in pixels per second.
@export var rise_speed := 90.0
## Upward launch speed for a stroke from the underwater floor, in pixels per second.
@export var floor_stroke_speed := 60.0
## Speed added by a stroke or held-item dive, in pixels per second.
@export var stroke_extra := 36.0
## Extra speed when a stroke or held-item dive reverses vertical motion.
@export var reversal_extra := 10.8
## Upward acceleration supplied by a held item, in pixels per second squared.
@export var carry_buoyancy := 1800.0
## Maximum passive ascent speed while holding an item, in pixels per second.
@export var carry_rise_speed := 60.0
## Upward speed after an underwater enemy bounce, in pixels per second.
@export var bounce_speed := 100.5
## Upward speed handed to the ordinary jump state on a held-Jump surface exit.
@export var surface_jump_speed := 247.5
## Playback rate of an empty-hand swimming stroke, in frames per second.
@export var stroke_fps := 9.0
## Fractional frame at which a completed stroke returns to floating art.
@export var stroke_end_frame := 2.85
## Held-item swimming playback rate while descending, in frames per second.
@export var carry_sink_fps := 9.6
