# SPDX-License-Identifier: AGPL-3.0-or-later
class_name DonutPart
extends Part


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("res://textures/ui/editor/parts/smw/donut_block.png")


static func is_multiplaceable() -> bool:
	return true


static func create() -> DonutPart:
	return load("res://scenes/level/parts/donut_part.tscn").instantiate()


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	$Graphics/Sprite.texture = SpriteLibrary.get_frames(&"spr_donut_res").get_frame_texture(&"default", 0)


func build() -> void:
	var platform := DonutPlatform.new()
	platform.sub_area = sub_area
	platform.position = position
	sub_area.add(platform)
