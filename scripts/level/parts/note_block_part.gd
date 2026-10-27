# SPDX-License-Identifier: AGPL-3.0-or-later
class_name NoteBlockPart
extends ContainerBlockPart


func _init() -> void:
	content_id = &"none"


func default_content() -> StringName:
	return &"none"


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("res://textures/ui/editor/parts/smw/note_block.png")


static func is_multiplaceable() -> bool:
	return true


static func create() -> NoteBlockPart:
	return load("res://scenes/level/parts/note_block_part.tscn").instantiate()


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	$Graphics/Sprite.texture = SpriteLibrary.get_frames(&"spr_noteblock").get_frame_texture(&"default", 0)


func build() -> void:
	var tile := NoteBlock.new()
	tile.sub_area = sub_area
	tile.position = position
	tile.content_id = content_id
	sub_area.add(tile)
