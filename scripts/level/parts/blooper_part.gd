# SPDX-License-Identifier: AGPL-3.0-or-later
class_name BlooperPart
extends Part
## The source resource has no type/attachment window. Legacy flags stay metadata.

@export var rules: BlooperRules = preload("res://resources/content/smw_blooper.tres")
var _decoration: EnemyPartDecoration


static func create() -> BlooperPart:
	return load("res://scenes/parts/blooper_part.tscn").instantiate()


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_enemies.tres")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("res://textures/ui/editor/parts/smw/blooper.png")


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	if SpriteLibrary.has_sprite(rules.editor_sprite):
		$Graphics/Sprite.texture = SpriteLibrary.get_frames(rules.editor_sprite).get_frame_texture(&"default", 2)
	# spr_blooper_res origin(1,8) and24px height put its top8px above the grid.
	$Graphics/Sprite.position = Vector2(0, -4)
	if _decoration == null:
		_decoration = EnemyPartDecoration.new()
		$Graphics.add_child(_decoration)
	_decoration.position = Vector2(-8, -8)
	_decoration.refresh(rules.editor_decorations, swe_data.get("wings", 0) == 1, swe_data.get("paracaidas", 0) == 1)
	EnemyPartPreview.align_contact(self, $Graphics/Sprite, 0, _decoration)


func build() -> void:
	var enemy: Blooper = load("res://scenes/entities/blooper.tscn").instantiate()
	enemy.rules = rules
	enemy.position = position + Vector2(8, 16)
	sub_area.add(enemy)
