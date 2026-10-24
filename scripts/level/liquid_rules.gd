# SPDX-License-Identifier: AGPL-3.0-or-later
class_name LiquidRules
extends Resource
## SMW water/lava assets and obj_lava_water's source movement table.

@export var water_sprite: StringName
@export var beach_sprite: StringName
@export var lava_sprite: StringName
@export var poison_sprite: StringName
@export var water_fill_sprite: StringName
@export var beach_fill_sprite: StringName
@export var lava_fill_sprite: StringName
@export var poison_fill_sprite: StringName
@export var water_splash_sprite: StringName
@export var lava_splash_sprite: StringName
@export var poison_splash_sprite: StringName
@export var splash_fps := 12.0
@export var speeds := PackedFloat32Array([12, 30, 48])
@export var hold_time := 2.0
@export var fps := 6.0
## obj_lava_water scales its theme's full sprite bbox 24x and follows camera x.
@export var contact_scale := Vector2(24, 1)
