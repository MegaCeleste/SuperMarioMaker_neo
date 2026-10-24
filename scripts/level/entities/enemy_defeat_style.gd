# SPDX-License-Identifier: AGPL-3.0-or-later
class_name EnemyDefeatStyle
extends Resource
## Shared source obj_enemy_dead art; families keep their own motion data.

@export var dead_sprite: StringName
@export var dead_frame := 2
@export var dead_spins := true
@export var dead_offset := Vector2(0, -8)
@export var dead_water_offset := -1.0
## Optional rotating source mask for liquid sampling, independent of draw flip.
@export var dead_mask_rect := Rect2()
