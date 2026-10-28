@icon("uid://b3njsqgklsg01")
class_name Part
extends Area2D
## A gameplay element in a [Level].
##
## [Part]s are what [SubArea]s are made of. They represent gameplay elements,
## which parts generate on request via [method build]. In SMM:WE this can be
## seen as an equivalent to [code]obj_parent_resource[/code].


## The [Level] this part is in.
var level: Level
## The [SubArea] this part is in.
var sub_area: SubArea
## Original object/terrain fields retained by SWE round-trip serialization.
var swe_data: Dictionary = {}
var swe_source_index := -1
## Which saved source the index belongs to; detached undo Parts can outlive it.
var swe_revision := 0
## Whether this part is currently being dragged around.
var held := false:
	set(v):
		if held == v:
			return
		held = v
		queue_redraw()
		if v:
			_hold()
		else:
			_unhold()

# Tween used for the held and placing animations.
var _tween: Tween
# The mouse position relative to the part while held. Used for determining the
# part position while being held.
var _grab_offset: Vector2
# The last calculated grid position. Used for checking when the user hovers over
# a different grid spot.
var _grid_pos: Vector2i
# Whether the hovered grid tile is free to place the held part on.
var _valid_space: bool = true
# The original grid spot this part was on prior to being held.
var _original_pos: Vector2i
var _original_z: int
# Whether the mouse is currently hovering over this part.
var _mouse_in: bool
# Whether the part has been moved out of its original position while held. Used
# to check when a variant window should be opened or closed.
var _moved_out: bool
# The process tick this part was spawned on. Used to prevent the part being
# immediately held once placed. (I'm sure there's a better way to handle this.)
var _start_frame := Engine.get_process_frames()
# The editor's press count when this part was spawned. Physics picking can
# deliver the placing press on a later frame (a high refresh rate frame without
# a physics tick), so that press must not grab the part either.
var _start_press := Editor.presses
var _coll_layers: int
var _window: EditorWindow
var _window_timer: SceneTreeTimer
var _drag_start: Vector2
var _content_origin: ContainerBlockPart


## Gets this part's [PaletteCategory].
static func get_category() -> PaletteCategory:
	return load("uid://wtetnd7c3nmk")


## Gets the name of this part based on the [param environment].
@warning_ignore("unused_parameter")
static func get_part_name(environment: SubArea) -> String:
	return "Part"


## Gets the part's 60x60 icon based on the [param environment]. Only the center
## 54x54 region is always visible, the rest are additional compensation for
## animations where the icon moves.
@warning_ignore("unused_parameter")
static func get_part_icon(environment: SubArea) -> Texture2D:
	return ImageTexture.create_from_image(
			Image.create(60, 60, false, Image.FORMAT_RGBA8))


## Gets the part icon's [enum TextureFilter] to draw it with. For example, this
## can be [constant CanvasItem.TEXTURE_FILTER_NEAREST] for retro styles and
## [constant CanvasItem.TEXTURE_FILTER_LINEAR] for smooth styles.
@warning_ignore("unused_parameter")
static func get_part_icon_filter(environment: SubArea) -> TextureFilter:
	if environment.level.game_style == Level.GameStyle.NSMBU:
		return TEXTURE_FILTER_LINEAR
	else:
		return TEXTURE_FILTER_NEAREST


## Returns [code]true[/code] if multiple of this object can be placed with one
## stroke (e.g. the ground).
static func is_multiplaceable() -> bool:
	return false


## Checks for whether this part is placeable at the given [param grid_pos].
static func is_placeable(grid_pos: Vector2i, world: World2D) -> bool:
	return _check_rect(Rect2i(grid_pos, Vector2i(1, 1)), world)


## Whether the palette may place another one of this part in [param area].
## Parts with a per-course limit (such as doors) override this.
@warning_ignore("unused_parameter")
static func can_place_more(area: SubArea) -> bool:
	return true


## Creates an instance of this [Part].
static func create() -> Part:
	return load("uid://jr7c4ykh8awq").instantiate()


## Useful when creating your own part and overriding [method is_placeable].
## Checks whether the given [param rect], in grid coordinates, is empty.
static func _check_rect(rect: Rect2i, world: World2D) -> bool:
	var query = PhysicsShapeQueryParameters2D.new()
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 1 << 8
	query.transform.origin = Level.from_grid(rect.size) / 2 + Level.from_grid(rect.position)
	query.shape = RectangleShape2D.new()
	query.shape.size = Level.from_grid(rect.size) - Vector2(2, 2)
	return world.direct_space_state.intersect_shape(query, 1).is_empty()


func _ready() -> void:
	mouse_entered.connect(_mouse_update.bind(true))
	mouse_exited.connect(_mouse_update.bind(false))
	z_index = %Graphics.z_index - 1


func _process(_delta: float) -> void:
	if held:
		# held behavior
		queue_redraw()
		global_position = get_global_mouse_position() - _grab_offset
		var new_grid_pos = Level.to_grid(global_position + Vector2(8, 8))
		if new_grid_pos != _grid_pos:
			# choosing which sound to play
			var sound = preload("uid://rlah407gh46u")
			if _moved_out == false:
				_moved_out = true
				_stop_window_timer()
				if _window != null:
					_window.close()
				sound = preload("uid://b87gjrl17xs2k")
			if not (UISoundPlayer.stream == preload("uid://b87gjrl17xs2k")
					and UISoundPlayer.playing):
				UISoundPlayer.stream = sound
				UISoundPlayer.play()
			_check_validity()


func _input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	if event.button_index != MouseButton.MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		held = false


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int
		) -> void:
	if _is_placing_press():
		return
	if not is_instance_valid(level) or not is_instance_valid(level.editor) or not level.editor.part_interact:
		return
	if level.editor.held_part != null and level.editor.held_part != self:
		return
	if self is GroundPart and level.editor.hovered_part is SlopePart:
		return
	if event is not InputEventMouseButton:
		return
	if level.editor.erasing != Editor.EraseMode.NONE:
		return
	if event.button_index == MouseButton.MOUSE_BUTTON_LEFT and event.pressed:
		held = true
	elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
		_stop_window_timer()
		_create_window()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and held and is_instance_valid(level) \
			and is_instance_valid(level.editor):
		level.editor.held_part = null


func _draw():
	if level == null or is_queued_for_deletion():
		return
	if held:
		var color
		if _valid_space:
			color = Color(0, 0, 1, 0.5)
		else:
			color = Color(1, 0, 0, 0.5)
		_draw_highlight(Level.from_grid(_grid_pos) - global_position, color)
	elif _mouse_in and level.editor != null and level.editor.part_interact \
			and level.editor.held_part == null:
		_draw_highlight(Vector2(0, 0), Color(0, 0, 1, 0.5))


## Called when the [member level] and [member sub_area] are valid. Part
## initialization that relies on these should be put here.
func load(placed_from_editor := false) -> void:
	_grid_pos = Level.to_grid(global_position)
	if placed_from_editor:
		_anim_place()


## Erases the part. [param silent] is used when the part gets deleted for any
## other reason than being erased by the user.
## Editor gestures use Editor.erase_part() to retain the Part for undo.
func erase(silent := false) -> void:
	queue_free()
	if not silent:
		UISoundPlayer.stream = preload("uid://2axkkfi5xrx8")
		UISoundPlayer.play()


## Builds the gameplay element this part represents in the [member
## SubArea.foreground].
func build() -> void:
	pass


func can_erase() -> bool:
	return true


## Variant windows and undo use stable IDs rather than UI button positions.
func get_variants() -> Array[Dictionary]:
	return []


func get_variant() -> StringName:
	return &""


func set_variant(_id: StringName) -> void:
	pass


## Independent toggles (such as wings and a parachute) do not change type IDs.
func get_modifiers() -> Array[Dictionary]:
	return []


func has_modifier(_id: StringName) -> bool:
	return false


func set_modifier(_id: StringName, _enabled: bool) -> void:
	pass


## Type swaps can also remove dependent attachments. Undo restores both.
func get_variant_state() -> Dictionary:
	var modifiers := {}
	for option in get_modifiers():
		modifiers[option.id] = has_modifier(option.id)
	return {"id": get_variant(), "modifiers": modifiers}


func restore_variant_state(state: Dictionary) -> void:
	set_variant(state.id)
	for id: StringName in state.modifiers:
		set_modifier(id, state.modifiers[id])


## Environment changes may remove dependent attachments in the same history action.
func get_environment_state() -> Dictionary:
	return {}


func restore_environment_state(_state: Dictionary) -> void:
	pass


func refresh_environment() -> void:
	pass


## Called when the part is held.
func _hold() -> void:
	_drag_start = position
	_coll_layers = collision_layer
	collision_layer = 0

	_original_pos = _grid_pos
	_original_z = %Graphics.z_index
	_grab_offset = get_global_mouse_position() - global_position
	_moved_out = false

	z_index = GameConstants.Layers.Z_HELD_PART
	%Graphics.z_index = GameConstants.Layers.Z_HELD_GRAPHICS
	level.editor.held_part = self

	_window_timer = get_tree().create_timer(0.5)
	_window_timer.timeout.connect(_create_window)

	_anim_held()
	_create_touch_effect()

	UISoundPlayer.stream = preload("uid://cjtdcx7crghtw")
	UISoundPlayer.play()
	Cursor.down = true


## Called when the part is dropped.
func _unhold() -> void:
	collision_layer = _coll_layers
	%Graphics.z_index = _original_z
	z_index = _original_z - 1
	level.editor.held_part = null

	_tween.kill()
	_anim_place()
	_check_validity()
	_stop_window_timer()
	%Graphics.rotation = 0
	if level.editor.try_insert_content(self, _grid_pos):
		Cursor.down = false
		return
	if not _valid_space and is_instance_valid(_content_origin) \
			and level.editor.try_insert_content(self, Level.to_grid(_content_origin.position)):
		Cursor.down = false
		return
	_content_origin = null

	if not _valid_space:
		_grid_pos = _original_pos
	global_position = Level.from_grid(_grid_pos)
	%Graphics.rotation = 0
	level.editor.history.record_move(self, _drag_start, position)

	UISoundPlayer.stream = preload("uid://2x6kk0s4njjp")
	UISoundPlayer.play()
	Cursor.down = false


## Override this to customize the appearance of the highlight, as it is a single
## tile by default. Expect [param pos] to be relative to this part's position.
func _draw_highlight(pos: Vector2, color: Color) -> void:
	draw_rect(Rect2(pos, Level.GRID_SIZE), color)


func _anim_place() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(%Graphics, "scale", Vector2(1, 1), 0.1) \
			.from(Vector2(0.1, 0.1))


func _anim_held() -> void:
	_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(%Graphics, "rotation", TAU / 30, 0.2).from(0) \
			.set_ease(Tween.EASE_OUT)
	_tween.tween_property(%Graphics, "rotation", TAU / -30, 0.4) \
			.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(%Graphics, "rotation", 0, 0.2) \
			.set_ease(Tween.EASE_IN)
	_tween.set_loops()


func _mouse_update(state: bool) -> void:
	if level == null or level.editor == null:
		return
	_mouse_in = state
	queue_redraw()
	if _mouse_in:
		if not (self is GroundPart and level.editor.hovered_part is SlopePart):
			level.editor.hovered_part = self
	elif level.editor.hovered_part == self:
		level.editor.hovered_part = null


func _check_validity() -> void:
	_grid_pos = Level.to_grid(global_position + Vector2(8, 8))
	var query = PhysicsPointQueryParameters2D.new()
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 1 << 8
	query.exclude = [get_rid()]
	query.position = Level.from_grid(_grid_pos) + Level.GRID_SIZE / 2
	_valid_space = get_world_2d().direct_space_state \
			.intersect_point(query, 1).is_empty()
	if not _valid_space and level.editor.content_target(_grid_pos, self) != null:
		_valid_space = true


func _create_touch_effect() -> void:
	level.editor.touch_effect = preload("uid://chv4mkls3f538") \
			.instantiate()
	level.add_child(level.editor.touch_effect)
	level.editor.touch_effect.global_position = get_global_mouse_position()


# Whether the current mouse press is the one that placed this part.
func _is_placing_press() -> bool:
	return Engine.get_process_frames() == _start_frame or Editor.presses == _start_press


func _create_window() -> void:
	if (get_variants().is_empty() and get_modifiers().is_empty()) or not held or not is_inside_tree():
		return
	_window = preload("uid://dyw1evq8k8n58").instantiate()
	_window.part = self
	_window.target_position = Level.from_grid(_grid_pos) + Level.GRID_SIZE / 2
	level.editor.get_node(^"%WindowLayer").add_child(_window)


func _stop_window_timer() -> void:
	if _window_timer != null:
		if _window_timer.timeout.is_connected(_create_window):
			_window_timer.timeout.disconnect(_create_window)
