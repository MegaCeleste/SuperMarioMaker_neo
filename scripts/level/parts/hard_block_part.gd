# SPDX-License-Identifier: AGPL-3.0-or-later
class_name HardBlockPart
extends Part


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_terrain.tres")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("res://textures/ui/editor/parts/smw/hard_block.png")


static func is_multiplaceable() -> bool:
	return true


static func create() -> HardBlockPart:
	return load("res://scenes/parts/hard_block_part.tscn").instantiate()


static func sprite_for(area: SubArea) -> StringName:
	return &"spr_madera" if area.level_theme in [Level.LevelTheme.MANSION, Level.LevelTheme.AIRSHIP] else &"spr_block_rock"


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	$Graphics/Sprite.texture = SpriteLibrary.get_frames(sprite_for(sub_area)).get_frame_texture(&"default", 0)


func build() -> void:
	var tile := HardBlock.new()
	tile.position = position
	tile.sub_area = sub_area
	sub_area.add(tile)
