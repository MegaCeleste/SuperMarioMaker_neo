# SPDX-License-Identifier: AGPL-3.0-or-later
class_name FireFlowerPart
extends Part

@export var progressive := false


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_items.tres")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("res://textures/ui/editor/parts/smw/fire_flower.png")


static func create() -> FireFlowerPart:
	return load("res://scenes/parts/fire_flower_part.tscn").instantiate()


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	_refresh()


func get_variants() -> Array[Dictionary]:
	return [{"id": &"flower", "label": &"EDITOR_CONTENT_FIRE_FLOWER", "icon": get_part_icon(sub_area)},
		{"id": &"progressive_flower", "label": &"EDITOR_CONTENT_PROGRESSIVE_FLOWER",
		"icon": SpriteLibrary.get_frames(&"spr_fireflower_res").get_frame_texture(&"default", 1)}]


func get_variant() -> StringName:
	return &"progressive_flower" if progressive else &"flower"


func set_variant(id: StringName) -> void:
	if id not in [&"flower", &"progressive_flower"]:
		return
	progressive = id == &"progressive_flower"
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	$Graphics/Sprite.texture = SpriteLibrary.get_frames(&"spr_fireflower_res").get_frame_texture(&"default", int(progressive))


func build() -> void:
	var flower := FireFlower.new()
	flower.progressive = progressive
	flower.position = position + Vector2(8, 16)
	sub_area.add(flower)
