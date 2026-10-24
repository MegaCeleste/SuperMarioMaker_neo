# SPDX-License-Identifier: AGPL-3.0-or-later
class_name CheepCheepPart
extends Part
## Native type swap retains wings, drops parachute and updates the tool card.

const VARIANTS: Array[CheepCheepVariant] = [preload("res://resources/content/smw_cheep_cheep_red.tres"),
	preload("res://resources/content/smw_cheep_cheep_yellow.tres")]
@export var variant: CheepCheepVariant = preload("res://resources/content/smw_cheep_cheep_red.tres"):
	set(value):
		variant = value
		if is_node_ready():
			_refresh_preview()
@export var wings := false
@export var parachute := false
var _decoration: EnemyPartDecoration


static func create() -> CheepCheepPart:
	return load("res://scenes/parts/cheep_cheep_part.tscn").instantiate()


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_enemies.tres")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("res://textures/ui/editor/parts/smw/cheep_cheep.png")


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	_refresh_preview()


func _refresh_preview() -> void:
	if SpriteLibrary.has_sprite(variant.editor_sprite):
		$Graphics/Sprite.texture = SpriteLibrary.get_frames(variant.editor_sprite).get_frame_texture(&"default", 2)
	# Source 19px canvas with origin(2,2), centered inside native16px Graphics.
	$Graphics/Sprite.position = Vector2(-0.5, -0.5)
	if _decoration == null:
		_decoration = EnemyPartDecoration.new()
		$Graphics.add_child(_decoration)
	_decoration.position = Vector2(-8, -8)
	_decoration.refresh(variant.flight, wings, parachute)
	EnemyPartPreview.align_contact(self, $Graphics/Sprite, 0, _decoration)


func is_in_water() -> bool:
	var liquid := sub_area.liquid
	return is_instance_valid(liquid) and liquid.is_water() \
			and global_position.y >= liquid.global_position.y + 16


func build() -> void:
	var enemy: CheepCheep = load("res://scenes/entities/cheep_cheep.tscn").instantiate()
	enemy.variant = variant
	enemy.wings = wings
	enemy.parachute = parachute
	enemy.water_mode = is_in_water()
	enemy.position = position + Vector2(8, 16)
	sub_area.add(enemy)


func get_variants() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for choice in VARIANTS:
		result.append({"id": choice.id, "label": choice.label, "icon": choice.icon})
	return result


func get_variant() -> StringName:
	return variant.id


func set_variant(id: StringName) -> void:
	for choice in VARIANTS:
		if choice.id == id:
			parachute = false # Other_11 copies only wings into the replacement.
			variant = choice


func get_modifiers() -> Array[Dictionary]:
	return variant.flight.editor_options()


func has_modifier(id: StringName) -> bool:
	return wings if id == &"wings" else parachute if id == &"parachute" else false


func set_modifier(id: StringName, enabled: bool) -> void:
	if id == &"wings":
		wings = enabled
	elif id == &"parachute":
		parachute = enabled
	if is_node_ready():
		_refresh_preview()


static func variant_for_object(id: String) -> CheepCheepVariant:
	return VARIANTS[1] if id == VARIANTS[1].object_id else VARIANTS[0]
