# SPDX-License-Identifier: AGPL-3.0-or-later
class_name HiddenBlockPart
extends ContainerBlockPart


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_terrain.tres")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("res://textures/ui/editor/parts/smw/invisible_question_block.png")


static func is_multiplaceable() -> bool:
	return true


static func create() -> HiddenBlockPart:
	return load("res://scenes/level/parts/hidden_block_part.tscn").instantiate()


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	var index := 0
	match sub_area.level_theme:
		Level.LevelTheme.UNDERGROUND, Level.LevelTheme.MANSION: index = 1
		Level.LevelTheme.UNDERWATER: index = 2
		Level.LevelTheme.DESERT: index = 3
		Level.LevelTheme.FOREST: index = 4
	$Graphics/Sprite.texture = SpriteLibrary.get_frames(&"spr_block_hidden").get_frame_texture(&"default", index)


func build() -> void:
	var tile := HiddenBlock.new()
	tile.position = position
	tile.sub_area = sub_area
	tile.sprout = make_sprout()
	sub_area.add(tile)
