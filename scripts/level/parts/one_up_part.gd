# SPDX-License-Identifier: AGPL-3.0-or-later
class_name OneUpPart
extends Part


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_items.tres")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("res://textures/ui/editor/parts/smw/1up.png")


static func create() -> OneUpPart:
	return load("res://scenes/parts/one_up_part.tscn").instantiate()


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	$Graphics/Sprite.texture = SpriteLibrary.get_frames(&"spr_1up").get_frame_texture(&"default", 0)
	$Graphics/Sprite.position.y = 1


func build() -> void:
	var item := OneUp.new()
	item.position = position + Vector2(8, 16)
	sub_area.add(item)
