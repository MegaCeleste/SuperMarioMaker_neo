# SPDX-License-Identifier: AGPL-3.0-or-later
class_name IceBlockPart
extends Part


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("res://textures/ui/editor/parts/smw/ice_block.png")


static func is_multiplaceable() -> bool:
	return true


static func create() -> IceBlockPart:
	return load("res://scenes/parts/ice_block_part.tscn").instantiate()


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	$Graphics/Sprite.texture = SpriteLibrary.get_frames(&"spr_block_ice").get_frame_texture(&"default", 0)


func build() -> void:
	var tile := IceBlock.new()
	tile.position = position
	tile.sub_area = sub_area
	sub_area.add(tile)
