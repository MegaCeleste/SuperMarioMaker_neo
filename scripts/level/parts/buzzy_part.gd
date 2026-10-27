# SPDX-License-Identifier: AGPL-3.0-or-later
class_name BuzzyPart
extends Part

const VARIANTS: Array[BuzzyVariant] = [preload("res://resources/content/smw_buzzy_beetle.tres"),
	preload("res://resources/content/smw_buzzy_empty.tres")]
@export var variant: BuzzyVariant = preload("res://resources/content/smw_buzzy_beetle.tres"):
	set(value):
		variant = value
		if is_node_ready():
			_refresh_preview()
@export var wings := false
@export var parachute := false
var _decoration: EnemyPartDecoration
var _ceiling := false


static func create() -> BuzzyPart:
	return load("res://scenes/level/parts/buzzy_part.tscn").instantiate()


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_enemies.tres")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("res://textures/ui/editor/parts/smw/buzzy_beetle.png")


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	_refresh_preview()


func _process(delta: float) -> void:
	super(delta)
	if _ceiling != is_ceiling_attached():
		_refresh_preview()


func is_ceiling_attached() -> bool:
	return not (wings or parachute or variant.empty_shell) and CeilingAttachment.is_attached(self)


func _refresh_preview() -> void:
	_ceiling = is_ceiling_attached()
	var preview := $Graphics.get_child(0) as Sprite2D
	preview.position = Vector2.ZERO
	var sprite_name := variant.winged_editor_sprite if wings and not variant.empty_shell else variant.editor_sprite
	if SpriteLibrary.has_sprite(sprite_name):
		$Graphics.get_child(0).texture = SpriteLibrary.get_frames(sprite_name).get_frame_texture(&"default", 0)
	$Graphics.get_child(0).flip_v = _ceiling
	if _decoration == null:
		_decoration = EnemyPartDecoration.new()
		_decoration.name = "Attachments"
		$Graphics.add_child(_decoration)
	_decoration.position = Vector2(-8, -8)
	_decoration.refresh(variant.flight, wings and not variant.empty_shell, parachute)
	EnemyPartPreview.align_contact(self, preview, 1 if _ceiling else 0, _decoration)


func build() -> void:
	if variant.empty_shell:
		var shell: KoopaShell = load("res://scenes/level/entities/koopa_shell.tscn").instantiate()
		shell.variant = variant
		shell.position = position + Vector2(8, 16)
		sub_area.add(shell)
	else:
		var enemy: BuzzyBeetle = load("res://scenes/level/entities/buzzy_beetle.tscn").instantiate()
		enemy.variant = variant
		enemy.position = position + Vector2(8, 16)
		enemy.ceiling = is_ceiling_attached()
		enemy.get_node("FlightComponent").wings = wings
		enemy.get_node("FlightComponent").parachute = parachute
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
			if choice.empty_shell:
				wings = false # Resource swap keeps only paracaidas in the source.
			variant = choice


func get_modifiers() -> Array[Dictionary]:
	var options := variant.flight.editor_options()
	return [options[1]] if variant.empty_shell else options


func has_modifier(id: StringName) -> bool:
	return wings if id == &"wings" else parachute if id == &"parachute" else false


func set_modifier(id: StringName, enabled: bool) -> void:
	if id == &"wings" and not variant.empty_shell:
		wings = enabled
	elif id == &"parachute":
		parachute = enabled
	if is_node_ready():
		_refresh_preview()


static func variant_for_object(id: String) -> BuzzyVariant:
	return VARIANTS[1] if id == VARIANTS[1].object_id else VARIANTS[0]
