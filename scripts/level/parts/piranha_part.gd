# SPDX-License-Identifier: AGPL-3.0-or-later
class_name PiranhaPart
extends Part
## Standalone jumping/fire plants. Pipe-contained plants are a different Part.

const VARIANTS: Array[PiranhaVariant] = [preload("res://resources/content/smw_piranha_jump.tres"),
	preload("res://resources/content/smw_piranha_fire.tres")]
@export var variant: PiranhaVariant = preload("res://resources/content/smw_piranha_jump.tres"):
	set(value):
		variant = value
		if is_node_ready():
			_refresh_preview()
@export var wings := false
@export var parachute := false
var _decoration: EnemyPartDecoration
var _orientation := 0


static func create() -> PiranhaPart:
	return load("res://scenes/level/parts/piranha_part.tscn").instantiate()


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_enemies.tres")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("res://textures/ui/editor/parts/smw/piranha_plant.png")


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	refresh_environment()
	_refresh_preview()


func attachment_orientation() -> int:
	return 0 if variant.fire else CeilingAttachment.orientation(self)


func _process(delta: float) -> void:
	super(delta)
	if _orientation != attachment_orientation():
		_refresh_preview()


func _refresh_preview() -> void:
	_orientation = attachment_orientation()
	var sprite: Sprite2D = $Graphics/Sprite
	if SpriteLibrary.has_sprite(variant.editor_sprite):
		sprite.texture = SpriteLibrary.get_frames(variant.editor_sprite).get_frame_texture(&"default", 2)
	sprite.centered = false
	sprite.offset = -variant.editor_origin
	sprite.position = Vector2(-8, -8)
	sprite.rotation = 0
	sprite.scale = Vector2.ONE
	match _orientation:
		1:
			sprite.position.y += 16
			sprite.scale.y = -1
		2:
			sprite.position.x += 16
			sprite.rotation = PI / 2
		3:
			sprite.position.y += 16
			sprite.rotation = -PI / 2
	if _decoration == null:
		_decoration = EnemyPartDecoration.new()
		$Graphics.add_child(_decoration)
	_decoration.position = Vector2(-8, -8)
	_decoration.z_index = -1 if variant.fire else 0
	_decoration.refresh(variant.flight, wings and _orientation == 0, parachute and _orientation == 0)
	EnemyPartPreview.align_contact(self, sprite, _orientation, _decoration)


func build() -> void:
	refresh_environment()
	var enemy: PiranhaPlant = load("res://scenes/level/entities/piranha_plant.tscn").instantiate()
	enemy.variant = variant
	enemy.wings = wings
	enemy.parachute = parachute
	enemy.attachment = attachment_orientation()
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
			variant = choice


func get_modifiers() -> Array[Dictionary]:
	var options := variant.flight.editor_options()
	for option in options:
		option.disabled = attachment_orientation() != 0
	return options


func has_modifier(id: StringName) -> bool:
	return wings if id == &"wings" else parachute if id == &"parachute" else false


func set_modifier(id: StringName, enabled: bool) -> void:
	if id == &"wings":
		wings = enabled
	elif id == &"parachute":
		parachute = enabled
	if is_node_ready():
		_refresh_preview()


func get_environment_state() -> Dictionary:
	return {} if held and _moved_out else {"wings": wings, "parachute": parachute}


func restore_environment_state(state: Dictionary) -> void:
	wings = state.wings
	parachute = state.parachute
	_refresh_preview()


func refresh_environment() -> void:
	if attachment_orientation() != 0 and not (held and _moved_out):
		wings = false
		parachute = false
	if is_node_ready():
		_refresh_preview()


static func variant_for_object(id: String) -> PiranhaVariant:
	return VARIANTS[1] if id == VARIANTS[1].object_id else VARIANTS[0]
