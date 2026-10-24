# SPDX-License-Identifier: AGPL-3.0-or-later
class_name MontyPart
extends Part
## Source obj_monty_res has no type popup; wings and parachute toggle together.

const VARIANT = preload("res://resources/content/smw_monty.tres")
@export var variant: MontyVariant = VARIANT
@export var wings := false
@export var parachute := false
var _decoration: EnemyPartDecoration


static func create() -> MontyPart:
	return load("res://scenes/parts/monty_part.tscn").instantiate()


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_enemies.tres")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("res://textures/ui/editor/parts/smw/monty_mole.png")


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	_refresh_preview()


func _refresh_preview() -> void:
	var sprite: Sprite2D = $Graphics/Sprite
	if SpriteLibrary.has_sprite(variant.editor_sprite):
		sprite.texture = SpriteLibrary.get_frames(variant.editor_sprite).get_frame_texture(
				&"default", variant.editor_frame)
		sprite.centered = false
		sprite.offset = Vector2.ZERO
		# Source obj_monty_res draws its 27x24 art at origin (5,6) from the cell.
		sprite.position = -$Graphics.position - variant.editor_origin
	if _decoration == null:
		_decoration = EnemyPartDecoration.new()
		$Graphics.add_child(_decoration)
	_decoration.position = -$Graphics.position
	_decoration.refresh(variant.flight, wings, parachute)
	EnemyPartPreview.align_contact(self, sprite, 0, _decoration)
	queue_redraw()


func build() -> void:
	var body: Monty = load("res://scenes/entities/monty.tscn").instantiate()
	body.variant = variant
	body.wings = wings
	body.parachute = parachute
	# scr_edit_to_play creates (x + 8, y); spr_montymole's origin is (8, 0).
	# Native actors use their feet, 16px below that source origin.
	body.position = position + Vector2(8, 16)
	sub_area.add(body)


func get_modifiers() -> Array[Dictionary]:
	return variant.flight.editor_options()


func has_modifier(id: StringName) -> bool:
	return wings if id == &"wings" else parachute if id == &"parachute" else false


func set_modifier(id: StringName, enabled: bool) -> void:
	if id == &"wings":
		wings = enabled
	elif id == &"parachute":
		parachute = enabled
	if is_node_ready():
		_refresh_preview()


static func variant_for_object(_id: String) -> MontyVariant:
	return VARIANT
