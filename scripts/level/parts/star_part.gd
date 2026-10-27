# SPDX-License-Identifier: AGPL-3.0-or-later
class_name StarPart
extends Part


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_items.tres")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("res://textures/ui/editor/parts/smw/star.png")


static func create() -> StarPart:
	return load("res://scenes/level/parts/star_part.tscn").instantiate()


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	$Graphics/Sprite.texture = SpriteLibrary.get_frames(&"spr_star_res").get_frame_texture(&"default", 2)


func build() -> void:
	var star := SuperStar.new()
	star.position = position + Vector2(8, 16)
	sub_area.add(star)
