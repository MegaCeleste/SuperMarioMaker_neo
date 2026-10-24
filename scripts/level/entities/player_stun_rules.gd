# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PlayerStunRules
extends Resource
## SMW obj_sledgebro stun and obj_shake_mario's independent visual loop.

@export var duration := 80.0 / 60
@export var effect_sprite: StringName
@export var effect_fps := 15.0
@export var effect_offset := Vector2(0, -27) # Source Mario origin +5, feet -32.
