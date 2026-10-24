# SPDX-License-Identifier: AGPL-3.0-or-later
class_name GoombaPart
extends GaloombaPart
## OpenWE's obj_goomba_res. In SMW it creates a Galoomba, which flips into
## a holdable enemy on a normal stomp (obj_galoomba), rather than flattening.

const VARIANTS: Array[GoombaVariant] = [preload("res://resources/content/smw_goomba_normal.tres"),
	preload("res://resources/content/smw_goomba_goombud.tres")]
@export var wings := false
@export var parachute := false
var _decoration: EnemyPartDecoration

@export var variant: GoombaVariant = preload("res://resources/content/smw_goomba_normal.tres"):
	set(value):
		variant = value
		if is_node_ready():
			_refresh_preview()


static func create() -> GoombaPart:
	return load("res://scenes/parts/goomba_part.tscn").instantiate()


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	_refresh_preview()


func get_variants() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for choice in VARIANTS:
		options.append({"id": choice.id, "label": choice.label, "icon": choice.icon})
	return options


func get_variant() -> StringName:
	return variant.id


func set_variant(id: StringName) -> void:
	for choice in VARIANTS:
		if choice.id == id:
			variant = choice
			return


static func variant_for_object(id: String) -> GoombaVariant:
	for choice in VARIANTS:
		if choice.object_id == id:
			return choice
	return VARIANTS[0]


func _refresh_preview() -> void:
	var preview := $Graphics.get_child(0) as Sprite2D
	preview.position = Vector2.ZERO
	if SpriteLibrary.has_sprite(variant.walk_sprite):
		preview.texture = SpriteLibrary.get_frames(variant.walk_sprite).get_frame_texture(&"default", 0)
	if _decoration == null:
		_decoration = EnemyPartDecoration.new()
		_decoration.name = "Attachments"
		$Graphics.add_child(_decoration)
	_decoration.position = Vector2(-8, -8)
	_decoration.refresh(variant.flight, wings, parachute)
	EnemyPartPreview.align_contact(self, preview, 0, _decoration)


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


func build() -> void:
	var enemy := preload("res://scenes/entities/galoomba.tscn").instantiate()
	enemy.variant = variant
	enemy.get_node("FlightComponent").wings = wings
	enemy.get_node("FlightComponent").parachute = parachute
	enemy.position = position + Vector2(8, 16)
	sub_area.add(enemy)
