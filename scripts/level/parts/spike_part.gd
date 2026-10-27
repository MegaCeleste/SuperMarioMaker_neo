# SPDX-License-Identifier: AGPL-3.0-or-later
class_name SpikePart
extends Part


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("res://textures/ui/editor/parts/smw/spiketrap.png")


static func is_multiplaceable() -> bool:
	return true


static func create() -> SpikePart:
	return load("res://scenes/level/parts/spike_part.tscn").instantiate()


static func sprite_for(area: SubArea) -> StringName:
	return &"spr_pinchos_swin" if area.level_theme == Level.LevelTheme.UNDERWATER else &"spr_pinchos"


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	$Graphics/Sprite.texture = SpriteLibrary.get_frames(sprite_for(sub_area)).get_frame_texture(&"default", 0)


func build() -> void:
	var tile := SpikeTile.new()
	tile.position = position
	tile.sub_area = sub_area
	sub_area.add(tile)
