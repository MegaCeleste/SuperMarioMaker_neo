# SPDX-License-Identifier: AGPL-3.0-or-later
class_name MuncherVariant
extends EnemyDefeatStyle
## SMW's two physical-solid sizes, distinct source origins and editor flags.

@export var id: StringName
@export var object_id: String
@export var label: StringName
@export var icon: Texture2D
@export var body_sprite: StringName
@export var editor_sprite: StringName
@export var dark_editor_sprite: StringName
@export var editor_frame := 2
@export var editor_dark_frame := 2
@export var editor_origin := Vector2.ZERO
@export var canvas_size := Vector2(16, 16)
@export var mask_size := Vector2(14, 15)
@export var source_x_offset := 0.0
@export var flight: EnemyFlightProfile
@export var gravity := 720.0
@export var water_gravity := 72.0
@export var fall_speed := 240.0
@export var water_fall_speed := 60.0
@export var ground_drag := 360.0
@export var air_drag := 54.0
@export var bump_speed := 180.0
@export var water_bump_speed := 108.0
@export var landing_sound := ""
@export var crush_sound := "snd_klock"
@export var pow_smoke_sprite: StringName = &"spr_spinthump"
@export var buzzy_helmet_margin := 8.0
@export var spiny_helmet_margin := 5.0


func footprint() -> Rect2:
	return Rect2(Vector2(0, 16 - canvas_size.y), canvas_size)


func feet_offset() -> Vector2:
	return Vector2(canvas_size.x / 2, 16 - canvas_size.y + mask_size.y)
