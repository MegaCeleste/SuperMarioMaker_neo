# SPDX-License-Identifier: AGPL-3.0-or-later
class_name EnemyPartDecoration
extends Node2D
## Original editor overlays follow the Part graphics, including drag animation.


func refresh(profile: EnemyFlightProfile, wings: bool, parachute: bool) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var rules: EnemyFlightPhysics = preload("res://resources/content/smw_enemy_flight_physics.tres")
	if parachute:
		_add_style_sprite(rules.editor_parachute_sprite, profile.editor_parachute_offset)
	if wings:
		_add_style_sprite(profile.editor_wings_sprite, profile.editor_wings_offset)


func _add_style_sprite(sprite_name: StringName, at: Vector2) -> void:
	if not SpriteLibrary.has_sprite(sprite_name):
		return
	var sprite := SpriteLibrary.make_sprite(sprite_name)
	sprite.stop()
	sprite.frame = 2 # The represented editor slice is SMW.
	sprite.position = at
	add_child(sprite)
