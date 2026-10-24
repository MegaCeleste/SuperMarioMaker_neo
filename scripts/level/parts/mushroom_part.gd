# SPDX-License-Identifier: AGPL-3.0-or-later
class_name MushroomPart
extends Part
## Standalone mushroom placement reuses the existing powerup runtime.


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_items.tres")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("res://textures/ui/editor/parts/smw/mushroom.png")


static func create() -> MushroomPart:
	return load("res://scenes/parts/mushroom_part.tscn").instantiate()


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	if SpriteLibrary.has_sprite(&"spr_mushroom"):
		$Graphics/Sprite.texture = SpriteLibrary.get_frames(&"spr_mushroom").get_frame_texture(&"default", 0)


func build() -> void:
	var mushroom: Mushroom = preload("res://scenes/entities/mushroom.tscn").instantiate()
	mushroom.position = position + Vector2(8, 16)
	sub_area.add(mushroom)
