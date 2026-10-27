# SPDX-License-Identifier: AGPL-3.0-or-later
class_name CloudPart
extends Part


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("res://textures/ui/editor/parts/smw/cloud.png")


static func is_multiplaceable() -> bool:
	return true


static func create() -> CloudPart:
	return load("res://scenes/level/parts/cloud_part.tscn").instantiate()


static func texture_for(area: SubArea) -> Texture2D:
	return SpriteLibrary.get_frames(&"spr_nube").get_frame_texture(&"default", 1 if area.level_theme == Level.LevelTheme.UNDERWATER else 0)


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	$Graphics/Sprite.texture = texture_for(sub_area)


func build() -> void:
	var tile := CloudPlatform.new()
	tile.position = position
	tile.sub_area = sub_area
	sub_area.add(tile)
