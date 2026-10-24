class_name EditorWindow
extends PanelContainer

signal selected(id: StringName)

var part: Part
var target_position: Vector2

var _closing := false


func _ready() -> void:
	%SoundPlayer.play()
	if part != null:
		var content := VBoxContainer.new()
		content.name = "Content"
		add_child(content)
		if not part.get_modifiers().is_empty():
			var attachments := HBoxContainer.new()
			attachments.name = "Attachments"
			content.add_child(attachments)
			for option in part.get_modifiers():
				var toggle := Button.new()
				toggle.name = String(option.id)
				toggle.theme_type_variation = &"CoursebotLevelButton"
				toggle.tooltip_text = tr(option.label)
				toggle.icon = option.icon
				toggle.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				toggle.add_theme_constant_override("icon_max_width", 24)
				toggle.custom_minimum_size = Vector2(44, 44)
				toggle.toggle_mode = true
				toggle.disabled = option.get("disabled", false)
				toggle.button_pressed = part.has_modifier(option.id)
				toggle.toggled.connect(_modifier_toggled.bind(option.id))
				attachments.add_child(toggle)
		var options := HBoxContainer.new()
		options.name = "Options"
		content.add_child(options)
		var group := ButtonGroup.new()
		if part is ContainerBlockPart:
			var current := Button.new()
			current.name = "StoredContent"
			current.theme_type_variation = &"CoursebotLevelButton"
			current.icon = part.content_texture()
			current.text = tr("EDITOR_CONTENT_EMPTY") if current.icon == null else ""
			current.tooltip_text = tr("EDITOR_CONTENT_DRAG_OUT")
			current.custom_minimum_size = Vector2(84, 84)
			current.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			current.expand_icon = true
			current.add_theme_constant_override("icon_max_width", 64)
			current.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			current.disabled = current.icon == null
			current.button_down.connect(_take_content)
			options.add_child(current)
		for option in ([] if part is ContainerBlockPart else part.get_variants()):
			var button := Button.new()
			button.theme_type_variation = &"CoursebotLevelButton"
			button.name = String(option.id)
			button.tooltip_text = tr(option.label)
			button.disabled = option.get("disabled", false)
			button.icon = option.icon
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.add_theme_constant_override("icon_max_width", 54)
			button.toggle_mode = true
			button.button_group = group
			button.button_pressed = part.get_variant() == option.id
			button.custom_minimum_size = Vector2(84, 84)
			button.pressed.connect(select.bind(option.id))
			options.add_child(button)
		part.level.editor.part_interact = false
	var from_screen := get_canvas_transform().affine_inverse()
	var screen_target := part.get_canvas_transform() * target_position if part != null else target_position
	position = from_screen * screen_target - get_combined_minimum_size() - Vector2(12, 12)
	var bounds := from_screen * get_viewport().get_visible_rect()
	position = position.clamp(bounds.position, bounds.end - get_combined_minimum_size())
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1, 1), 0.1).from(Vector2(0, 0))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not Rect2(Vector2.ZERO, size).has_point(
			get_global_transform_with_canvas().affine_inverse() * event.position):
		if event.pressed:
			close()
			get_viewport().set_input_as_handled()


func _modifier_toggled(enabled: bool, id: StringName) -> void:
	if not _closing and is_instance_valid(part):
		var before := part.get_variant()
		part.level.editor.set_part_modifier(part, id, enabled)
		if part.get_variant() != before:
			close()


func _take_content() -> void:
	if _closing or not is_instance_valid(part):
		return
	close()
	part.level.editor.take_content.call_deferred(part)


func select(id: StringName) -> void:
	if _closing:
		return
	if is_instance_valid(part):
		part.level.editor.set_part_variant(part, id)
	selected.emit(id)
	close()


func close() -> void:
	if _closing:
		return
	_closing = true
	if is_instance_valid(part) and is_instance_valid(part.level) and part.level.editor != null:
		part.level.editor.part_interact = part.level.status == Level.Status.EDITING
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0, 0), 0.1)
	tween.tween_callback(queue_free)
