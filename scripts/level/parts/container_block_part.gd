# SPDX-License-Identifier: AGPL-3.0-or-later
class_name ContainerBlockPart
extends Part
## Shared authored contents; the editor inserts physical Parts by drag/drop.

@export var content_id: StringName = &"coin":
	set(value):
		content_id = value
		if is_node_ready():
			_refresh_content()

@export var contains_mushroom: bool:
	get:
		return content_id == &"mushroom"
	set(value):
		if value:
			content_id = &"mushroom"
		elif contains_mushroom:
			content_id = default_content()


func default_content() -> StringName:
	return &"coin"


static func content_for(part: Part, target: ContainerBlockPart = null) -> StringName:
	if part is MushroomPart: return &"mushroom"
	if part is OneUpPart: return &"one_up"
	if part is FireFlowerPart: return &"progressive_flower" if part.progressive else &"flower"
	if part is StarPart: return &"star"
	if part is CoinPart:
		if target is NoteBlockPart: return &""
		return &"coin" if target is HiddenBlockPart else &"multi_coin"
	return &""


static func create_content(id: StringName) -> Part:
	match id:
		&"coin", &"multi_coin": return CoinPart.create()
		&"mushroom": return MushroomPart.create()
		&"one_up": return OneUpPart.create()
		&"star": return StarPart.create()
		&"flower", &"progressive_flower":
			var part := FireFlowerPart.create()
			part.progressive = id == &"progressive_flower"
			return part
	return null


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	_refresh_content()


# Stable data IDs for history/old callers; EditorWindow shows current contents.
func get_variants() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: StringName in [&"coin", &"multi_coin", &"mushroom", &"flower", &"progressive_flower", &"star", &"one_up", &"none"]:
		result.append({"id": id})
	return result


func get_variant() -> StringName:
	return content_id


func set_variant(id: StringName) -> void:
	if id in [&"coin", &"multi_coin", &"mushroom", &"flower", &"progressive_flower", &"star", &"one_up", &"none"]:
		content_id = id


func content_texture() -> Texture2D:
	var art: StringName = &"spr_coin"
	var frame := 0
	match content_id:
		&"none": return null
		&"mushroom": art = &"spr_mushroom"
		&"one_up": art = &"spr_1up"
		&"flower", &"progressive_flower":
			art = &"spr_fireflower_res"
			frame = int(content_id == &"progressive_flower")
		&"star": art = &"spr_star"
	return SpriteLibrary.get_frames(art).get_frame_texture(&"default", frame)


func _refresh_content() -> void:
	var content := %Graphics.get_node_or_null("Content") as Sprite2D
	if content == null:
		content = Sprite2D.new()
		content.name = "Content"
		content.position = Vector2(4, -4)
		content.scale = Vector2(0.5, 0.5)
		%Graphics.add_child(content)
	content.texture = content_texture()
	content.visible = content_id != default_content() and content_id != &"none"


func make_sprout() -> Sprout:
	match content_id:
		&"coin": return CoinSprout.new()
		&"multi_coin": return MultiCoinSprout.new()
		&"mushroom": return MushroomSprout.new()
		&"one_up": return OneUpSprout.new()
		&"flower", &"progressive_flower": return FireFlowerSprout.new(content_id == &"progressive_flower")
		&"star": return StarSprout.new()
	return null
