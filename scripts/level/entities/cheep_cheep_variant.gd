# SPDX-License-Identifier: AGPL-3.0-or-later
class_name CheepCheepVariant
extends EnemyDefeatStyle
## obj_cheepcheep / obj_cheepcheep2 identity and SMW motion, in native units.

@export var id: StringName
@export var object_id: String
@export var label: StringName
@export var icon: Texture2D
@export var swim_sprite: StringName
@export var editor_sprite: StringName
@export var bubble_sprite: StringName = &"spr_cheepcheep_bubble"
@export var fire_sprite: StringName = &"spr_fire_cheepcheep"
@export var poison_sprite: StringName = &"spr_purple_cheepcheep"
@export var ember_sprite: StringName = &"spr_fire_rest"
@export var flight: EnemyFlightProfile
@export var turn_time := 0.0
@export var aim_large_jump := false
@export var swim_speed := 30.0
@export var jump_speed := 48.0
@export var wing_jump_speed := 60.0
@export var small_jump := 180.0
@export var large_jump := 300.0
@export var gravity := 432.0
@export var fall_speed := 240.0
@export var horizontal_drag := 288.0
@export var float_gravity := 360.0
@export var float_fall_speed := 24.0
@export var sway_distance := 16.0
@export var sway_speed := 30.0
@export var sway_acceleration := 54.0
@export var glide_time := 2.0
@export var glide_acceleration := 108.0
@export var glide_speed := 12.0
@export var glide_rise_speed := 18.0
@export var animation_fps := 7.5
@export var wings_fps := 7.2
@export var glide_wings_fps := 15.0
