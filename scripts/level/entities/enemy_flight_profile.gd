# SPDX-License-Identifier: AGPL-3.0-or-later
class_name EnemyFlightProfile
extends Resource
## Sprite placement and per-family motion; flags belong to each Part/actor.

enum WingMotion { HOP_BURST, BOUNCE, VERTICAL, RIDE, CRUISE }

@export var motion := WingMotion.HOP_BURST
@export var turn_after_burst := false
## Actors that drive their own horizontal motion (obj_monty_chase) skip the
## shared slide so the chase acceleration is not overwritten.
@export var manual_walk := false
## Grounded wing hop for BOUNCE; zero keeps the shared Koopa value.
@export var wing_hop_speed := 0.0
@export var wings_sprite: StringName
@export var float_sprite: StringName
@export var wing_body_sprite: StringName
@export var wing_body_frame := -1
@export var hover_distance := 10.0
@export var hover_speed := 24.0
@export var hover_acceleration := 306.0
@export var wings_fps := 0.0
@export var loaded_wings_fps := 0.0
@export var parachute_swing := true
@export var parachute_fps := 6.0
@export var wings_offset := Vector2.ZERO
@export var mirror_wings_offset := false
@export var parachute_offset := Vector2.ZERO
@export var editor_wings_sprite: StringName
@export var editor_wings_offset := Vector2.ZERO
@export var editor_parachute_offset := Vector2(0, -16)
@export var wing_loss_offsets := PackedVector2Array([Vector2(9, 8), Vector2(-11, 8)])
@export var wing_loss_drop := false


func editor_options() -> Array[Dictionary]:
	var rules: EnemyFlightPhysics = preload("res://resources/content/smw_enemy_flight_physics.tres")
	var frames := SpriteLibrary.get_frames(rules.editor_icon_sprite)
	return [{"id": &"wings", "label": &"EDITOR_WINGS", "icon": frames.get_frame_texture(&"default", 1)},
		{"id": &"parachute", "label": &"EDITOR_PARACHUTE", "icon": frames.get_frame_texture(&"default", 2)}]
