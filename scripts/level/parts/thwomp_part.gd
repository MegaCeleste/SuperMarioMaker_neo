# SPDX-License-Identifier: AGPL-3.0-or-later
class_name ThwompPart
extends Part
## Source instance anchors are retained through size changes and signed SWE.

const SMALL = preload("res://resources/content/smw_thwomp_small.tres")
const GIANT = preload("res://resources/content/smw_thwomp_giant.tres")
const ROLLING = preload("res://resources/content/smw_grrrol_legacy.tres")
const ROLLING_SMALL = preload("res://resources/content/smw_grrrol_small.tres")
const ROLLING_GIANT = preload("res://resources/content/smw_grrrol_giant.tres")
const VARIANTS: Array[ThwompVariant] = [SMALL, GIANT, ROLLING, ROLLING_SMALL, ROLLING_GIANT]
@export var variant: ThwompVariant = SMALL
@export_enum("Down:1", "Left:2", "Right:3") var attack_direction := 1
@export var wings := false
@export var parachute := false
var _arrow: Sprite2D
var _decoration: EnemyPartDecoration


static func create() -> ThwompPart:
	return load("res://scenes/level/parts/thwomp_part.tscn").instantiate()


static func get_category() -> PaletteCategory:
	return load("res://resources/palette/category_enemies.tres")


static func get_part_icon(_environment: SubArea) -> Texture2D:
	return preload("res://textures/ui/editor/parts/smw/thwomp.png")


static func is_placeable(grid_pos: Vector2i, world: World2D) -> bool:
	return _check_rect(Rect2i(grid_pos, Vector2i(2, 2)), world)


static func is_variant_placeable(grid_pos: Vector2i, world: World2D, id: StringName) -> bool:
	for choice in VARIANTS:
		if choice.id == id:
			var footprint := choice.editor_bounds
			return _check_rect(Rect2i(grid_pos + Vector2i(footprint.position / 16), Vector2i(footprint.size / 16)), world)
	return is_placeable(grid_pos, world)


func load(placed_from_editor := false) -> void:
	super(placed_from_editor)
	$CollShape.shape = $CollShape.shape.duplicate()
	_refresh_preview()


func _process(delta: float) -> void:
	super(delta)
	if _arrow != null:
		_arrow.visible = not held


func _refresh_preview() -> void:
	var sprite: Sprite2D = $Graphics/Sprite
	if SpriteLibrary.has_sprite(variant.editor_sprite):
		sprite.texture = SpriteLibrary.get_frames(variant.editor_sprite).get_frame_texture(&"default", 2)
		sprite.centered = false
		sprite.offset = -SpriteLibrary.get_origin(variant.editor_sprite)
		sprite.position = -$Graphics.position + (variant.editor_draw_center if variant is GrrrolVariant else Vector2.ZERO)
	$CollShape.position = variant.editor_bounds.get_center()
	$CollShape.shape.size = variant.editor_bounds.size
	if _arrow == null:
		_arrow = Sprite2D.new()
		_arrow.name = "Direction"
		$Graphics.add_child(_arrow)
	if SpriteLibrary.has_sprite(variant.arrow_sprite):
		_arrow.texture = SpriteLibrary.get_frames(variant.arrow_sprite).get_frame_texture(&"default", 0)
	_arrow.position = variant.arrow_center - $Graphics.position
	_arrow.rotation = PI / 2 if attack_direction == 2 else -PI / 2 if attack_direction == 3 else 0.0
	_arrow.visible = not held
	if _decoration == null:
		_decoration = EnemyPartDecoration.new()
		$Graphics.add_child(_decoration)
	var profile := EnemyFlightProfile.new()
	profile.editor_wings_sprite = &"spr_wings_editor_16x16"
	profile.editor_wings_offset = Vector2(17, -25)
	profile.editor_parachute_offset = Vector2(8, -16)
	_decoration.position = -$Graphics.position
	# Every source Grrrol Draw override omits inherited editor decorations.
	_decoration.refresh(profile, wings and not variant is GrrrolVariant, parachute and not variant is GrrrolVariant)
	EnemyPartPreview.align_contact(self, sprite, 0, _decoration)
	queue_redraw()


func _hold() -> void:
	super()
	if _arrow != null:
		_arrow.hide()


func _unhold() -> void:
	super()
	if _arrow != null:
		_arrow.show()


func _input_event(viewport: Viewport, event: InputEvent, shape_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and not _is_placing_press() and level.editor != null \
			and level.editor.part_interact and level.editor.erasing == Editor.EraseMode.NONE:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var button := variant.arrow_button
		if point.x > button.position.x and point.x < button.end.x \
				and point.y > button.position.y and point.y < button.end.y:
			var state := get_variant_state()
			state.direction = (3 if attack_direction == 2 else 2) if variant is GrrrolVariant else attack_direction % 3 + 1
			level.editor.history.set_part_state(self, state, "Change direction")
			UISoundPlayer.stream = SoundLibrary.stream("snd_change_arrow")
			UISoundPlayer.play()
			viewport.set_input_as_handled()
			return
	super(viewport, event, shape_index)


func build() -> void:
	if variant is GrrrolVariant:
		var rolling: Grrrol = load("res://scenes/level/entities/grrrol.tscn").instantiate()
		rolling.variant = variant
		rolling.attack_direction = attack_direction
		rolling.position = position + variant.part_to_feet
		# scr_edit_to_play copies only direct_t, never either attachment flag.
		sub_area.add(rolling)
		return
	var body: Thwomp = load("res://scenes/level/entities/thwomp.tscn").instantiate()
	body.variant = variant
	body.attack_direction = attack_direction
	body.wings = wings
	body.parachute = parachute
	body.position = position + variant.part_to_feet
	sub_area.add(body)


func get_variants() -> Array[Dictionary]:
	# Neither small Thwomp nor legacy Grrrol declares a popup.
	if variant is GrrrolVariant or not variant.giant:
		return []
	var icon: Texture2D = get_part_icon(sub_area)
	var rolling: Texture2D = icon
	if SpriteLibrary.has_sprite(variant.alternate_editor_sprite):
		rolling = SpriteLibrary.get_frames(variant.alternate_editor_sprite).get_frame_texture(&"default", 2)
	return [{"id": GIANT.id, "label": GIANT.label, "icon": icon},
		{"id": ROLLING.id, "label": &"EDITOR_ENEMY_GRRROL", "icon": rolling}]


func get_variant() -> StringName:
	return variant.id


func set_variant(id: StringName) -> void:
	for choice in VARIANTS:
		if id == choice.id and choice != variant:
			if choice == ROLLING and variant == GIANT:
				_play_transform()
				position.y -= 16
			if choice is GrrrolVariant:
				wings = false
				parachute = false
			variant = choice
			attack_direction = 2 if choice is GrrrolVariant else 1
			_update_anchor()


func get_modifiers() -> Array[Dictionary]:
	if variant is GrrrolVariant:
		if variant.legacy:
			return []
		var icons := SpriteLibrary.get_frames(&"spr_window_button_SMW")
		return [{"id": &"large", "label": ROLLING_GIANT.label, "icon": icons.get_frame_texture(&"default", 0)},
			{"id": &"wings", "label": &"EDITOR_WINGS", "icon": icons.get_frame_texture(&"default", 1)},
			{"id": &"parachute", "label": &"EDITOR_PARACHUTE", "icon": icons.get_frame_texture(&"default", 2)}]
	if not variant.giant:
		return []
	var icons := SpriteLibrary.get_frames(&"spr_window_button_SMW")
	return [{"id": &"large", "label": GIANT.label, "icon": icons.get_frame_texture(&"default", 0)}]


func has_modifier(id: StringName) -> bool:
	if variant is GrrrolVariant:
		return variant == ROLLING_GIANT if id == &"large" else wings if id == &"wings" else parachute if id == &"parachute" else false
	return id == &"large" and variant.giant


func set_modifier(id: StringName, enabled: bool) -> void:
	if variant is GrrrolVariant:
		if id == &"large" and not variant.legacy:
			set_variant(ROLLING_GIANT.id if enabled else ROLLING_SMALL.id)
		elif id == &"wings":
			wings = enabled
		elif id == &"parachute":
			parachute = enabled
		if is_node_ready():
			_refresh_preview()
		return
	if id == &"large":
		set_variant(GIANT.id if enabled else SMALL.id)


func get_variant_state() -> Dictionary:
	return {"id": variant.id, "direction": attack_direction, "wings": wings, "parachute": parachute, "position": position}


func restore_variant_state(state: Dictionary) -> void:
	for choice in VARIANTS:
		if choice.id == state.id:
			variant = choice
	position = state.get("position", position)
	attack_direction = state.direction
	wings = state.wings
	parachute = state.parachute
	_update_anchor()


func _update_anchor() -> void:
	_grid_pos = Level.to_grid(position)
	_original_pos = _grid_pos
	_drag_start = position
	if is_node_ready():
		_refresh_preview()


func _play_transform() -> void:
	if not is_inside_tree():
		return
	var effect := SpriteLibrary.make_sprite(ROLLING.transform_sprite)
	effect.sprite_frames = SpriteLibrary.get_animations({"transform": [String(ROLLING.transform_sprite), 18, false]})
	effect.position = level.to_local(global_position)
	effect.animation_finished.connect(effect.queue_free)
	level.add_child(effect)
	effect.play(&"transform")


func _draw_highlight(pos: Vector2, color: Color) -> void:
	draw_rect(Rect2(variant.editor_bounds.position + pos, variant.editor_bounds.size), color)


func _check_validity() -> void:
	_grid_pos = Level.to_grid(global_position + Vector2(8, 8))
	var query := PhysicsShapeQueryParameters2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = variant.editor_bounds.size - Vector2(2, 2)
	query.shape = rectangle
	query.transform.origin = Level.from_grid(_grid_pos) + variant.editor_bounds.get_center()
	query.collision_mask = 1 << 8
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	_valid_space = get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


static func variant_for_object(id: String) -> ThwompVariant:
	for choice in VARIANTS:
		if choice.object_id == id:
			return choice
	return SMALL


static func icon_for_variant(id: StringName) -> Texture2D:
	for choice in VARIANTS:
		if choice.id == id:
			return SpriteLibrary.get_frames(choice.editor_sprite).get_frame_texture(&"default", 2)
	return get_part_icon(null)
