class_name Editor
extends Control
## The game's editor.
##
## The [Editor] manages the level view while editing the level. [Part]s are
## tightly integrated with the editor as it handles keeping track of held parts,
## whether they can be interacted with and how they are interacted with. It also
## shares a reference to the level itself for the rest of the editor UI.

## Emitted when the editor is ready (i.e. [member level] has been set).
signal loaded
signal erase_started
signal erase_stopped
signal part_type_changed
signal save_finished(path: String, error: int)

enum EraseMode {
	NONE,
	TOGGLE_ERASE,
	QUICK_ERASE,
}
enum PartType {
	OBJECTS,
	SOUNDS,
}

## Number of left mouse presses seen so far. A [Part] compares it with the value
## at its creation to ignore the press that placed it.
static var presses := 0

## The level this [Editor] is associated with.
var level: Level
## The currently held part.
var held_part: Part
## The part that the mouse is currently on.
var hovered_part: Part
## Whether the editor is in erase mode and how it has been activated.
var erasing := EraseMode.NONE:
	set = _set_erasing
var part_type := PartType.OBJECTS:
	set = _set_part_type
## The currently displayed touch effect. Used to limit one at a time.
var touch_effect: AnimatedSprite2D
## The editor [Grid].
var grid := Grid.new()
var dark_overlay = DarkOverlay.new()
## Whether parts can currently be placed and interacted with.
var part_interact := true
var music_offset := 0.0
var history: EditorHistory
var _history_controls: HBoxContainer
var _undo_button: Button
var _redo_button: Button
var _part_defaults: Dictionary[Script, StringName] = {}

# The last calculated grid spot the mouse is on.
var _last_mouse_pos: Vector2i
var _saving := false


func _ready():
	grid.z_index = -1
	grid.minor_color = Color("00000099")
	grid.major_color = Color("000000ff")
	grid.modulate = Color("ffffff40")
	
	theme = ThemeDB.get_project_theme()
	
	%LeftPanel.status = EditorPanel.Status.OPEN
	%TopPanel.status = EditorPanel.Status.OPEN
	%RightPanel.status = EditorPanel.Status.OPEN
	%Clapperboard.off_screen = false


func _process(_delta: float) -> void:
	_update_history_controls()
	_process_placing(true)
	
	if Input.is_action_pressed(&"quick_erase") and held_part == null \
			and part_interact:
		erasing = EraseMode.QUICK_ERASE
	elif erasing == EraseMode.QUICK_ERASE:
		erasing = EraseMode.NONE
	
	if erasing != EraseMode.NONE:
		var erase_button
		if erasing == EraseMode.TOGGLE_ERASE:
			erase_button = &"erase"
		elif erasing == EraseMode.QUICK_ERASE:
			erase_button = &"quick_erase"
		
		if Input.is_action_pressed(erase_button):
			Cursor.down = true
			if hovered_part != null:
				history.begin_stroke("Erase")
				erase_part(hovered_part)
		else:
			Cursor.down = false
			history.end_stroke()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		presses += 1
	if event is InputEventMouseButton and not event.pressed and history != null:
		# A contents drag also ends in Part._input on this same mouse release.
		history.end_stroke.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.ctrl_pressed or event.meta_pressed) and event.keycode in [KEY_Z, KEY_Y]:
		if level.status == Level.Status.EDITING and part_interact and held_part == null:
			if event.keycode == KEY_Y or event.shift_pressed:
				history.redo()
			else:
				history.undo()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_S and (event.ctrl_pressed or event.meta_pressed):
		get_viewport().set_input_as_handled()
		request_save(event.shift_pressed)
		return
	if event.is_action_pressed("place"):
		_process_placing(false)


## Returns the currently selected [Part] script from the card bar on the top
## panel. If no [Part] is selected, [code]null[/code] is returned.
func get_selected_part() -> Script:
	var card: EditorCard = preload("uid://dhdt3ovnv8ci2").get_pressed_button()
	if card == null:
		return null
	else:
		return card.part


## Places a tile at [param pos] and returns the placed [Part].
func place(pos: Vector2i) -> Part:
	UISoundPlayer.stream = preload("uid://2x6kk0s4njjp")
	UISoundPlayer.play()
	
	var part: Part = get_selected_part().create()
	if _part_defaults.has(part.get_script()):
		part.set_variant(_part_defaults[part.get_script()])
	var target := content_target(pos, part)
	if target != null:
		history.set_variant(target, ContainerBlockPart.content_for(part, target))
		part.free()
		return target
	part.global_position = Level.from_grid(pos)
	level.current_sub_area.add_part(part)
	part.load(true)
	history.record_place(part)
	
	return part


## Both existing-object drags and palette placement use the same destination.
func content_target(pos: Vector2i, item: Part) -> ContainerBlockPart:
	if ContainerBlockPart.content_for(item).is_empty():
		return null
	for part in level.current_sub_area.get_parts().get_children():
		if part is ContainerBlockPart and part != item and Level.to_grid(part.position) == pos:
			return part if not ContainerBlockPart.content_for(item, part).is_empty() else null
	return null


func try_insert_content(item: Part, pos: Vector2i) -> bool:
	var target := content_target(pos, item)
	if target == null:
		return false
	history.store_content(target, item, item._drag_start)
	item._content_origin = null
	UISoundPlayer.stream = preload("uid://2x6kk0s4njjp")
	UISoundPlayer.play()
	return true


## Drag the displayed content out; its release joins this one undo action.
func take_content(block: ContainerBlockPart) -> Part:
	var item := ContainerBlockPart.create_content(block.content_id)
	if item == null:
		return null
	history.begin_stroke("Take out content")
	history.set_variant(block, block.default_content())
	item.position = block.position
	level.current_sub_area.add_part(item)
	item.load()
	history.record_place(item)
	item._content_origin = block
	item.held = true
	item._grab_offset = Level.GRID_SIZE / 2
	item.global_position = get_global_mouse_position() - item._grab_offset
	return item


## OpenWE retains the selected enemy type on its card for subsequent placement.
func set_part_variant(part: Part, id: StringName) -> void:
	var valid := false
	for option in part.get_variants():
		if option.id == id and not option.get("disabled", false):
			valid = true
	if not valid:
		return
	history.set_variant(part, id)
	_remember_palette_variant(part)


func _remember_palette_variant(part: Part) -> void:
	if part is GoombaPart or part is KoopaPart or part is CheepCheepPart or part is PiranhaPart or part is HammerBroPart \
			or part is GrrrolPart or part is SemisolidPart or (part is ThwompPart and part.variant is GrrrolVariant):
		_part_defaults[part.get_script()] = part.get_variant()
		for card: EditorCard in %Cards.get_children():
			if card.part == part.get_script():
				card.refresh_icon()
		get_node("PaletteMenu/RingContainer/Control/PaletteRing").refresh_icons()


func get_palette_icon(part: Script) -> Texture2D:
	if part == SemisolidPart and _part_defaults.has(part):
		return SemisolidPart.icon_for(level.current_sub_area, SemisolidPart.VARIANTS.find(_part_defaults[part]))
	if part in [ThwompPart, GrrrolPart] and _part_defaults.has(part):
		return ThwompPart.icon_for_variant(_part_defaults[part])
	if part in [GoombaPart, KoopaPart, CheepCheepPart, PiranhaPart, HammerBroPart] and _part_defaults.has(part):
		var choices: Array = part.VARIANTS
		for choice in choices:
			if choice.id == _part_defaults[part]:
				return choice.icon
	return part.get_part_icon(level.current_sub_area)


func set_part_modifier(part: Part, id: StringName, enabled: bool) -> void:
	for option in part.get_modifiers():
		if option.id == id:
			history.set_modifier(part, id, enabled)
			if (part is HammerBroPart or part is GrrrolPart) and id == &"large":
				_remember_palette_variant(part)
			return


## Removes an editor Part while retaining it for native UndoRedo restoration.
func erase_part(part: Part) -> void:
	if not part.can_erase():
		return
	history.erase(part)
	UISoundPlayer.stream = preload("uid://2axkkfi5xrx8")
	UISoundPlayer.play()


## Saves through the worker using a snapshot of the current edit state.
func save_to_path(path: String) -> Dictionary:
	if _saving:
		return {"error": ERR_BUSY, "message": "A save is already in progress."}
	if level.status != Level.Status.EDITING:
		return {"error": ERR_UNAVAILABLE, "message": "Return to editing before saving."}
	_saving = true
	history.end_stroke()
	var previous_interact := part_interact
	part_interact = false
	var result: Dictionary = await LevelProcessor.save_swe(level, path)
	_saving = false
	part_interact = previous_interact and level.status == Level.Status.EDITING
	save_finished.emit(path, result.error)
	return result


## Save Changes uses the loaded path; Save New and Ctrl+Shift+S ask for a path.
func request_save(save_as := false) -> void:
	if _saving or level.status != Level.Status.EDITING:
		return
	if not save_as and not level.file_path.is_empty():
		_show_save_result(await save_to_path(level.file_path))
		return
	var picker := FileDialog.new()
	picker.title = "Save level"
	picker.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.filters = PackedStringArray(["*.swe ; SMM:WE levels"])
	var directory := GameSettings.LEVELS_PATH if DirAccess.dir_exists_absolute(GameSettings.LEVELS_PATH) else "res://"
	picker.current_dir = ProjectSettings.globalize_path(directory)
	var base_name := level.level_name.validate_filename() if not level.level_name.is_empty() else "Untitled"
	picker.current_file = base_name + ".swe"
	add_child(picker)
	part_interact = false
	picker.canceled.connect(func():
		part_interact = true
		picker.queue_free())
	picker.file_selected.connect(func(path: String):
		part_interact = true
		picker.queue_free()
		_show_save_result(await save_to_path(path)))
	picker.popup_centered_ratio(0.7)


func _show_save_result(result: Dictionary) -> void:
	if result.error != OK:
		var dialog := AcceptDialog.new()
		dialog.title = "Could not save level"
		dialog.dialog_text = result.message
		add_child(dialog)
		dialog.confirmed.connect(dialog.queue_free)
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_centered()
		return
	var notice := Label.new()
	notice.text = "Level saved"
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice.position.y = 90
	add_child(notice)
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(notice, "modulate:a", 0, 0.3)
	tween.tween_callback(notice.queue_free)


## Called by the [Level] when it has given the editor a reference to itself and
## the editor needs to do initialization with it.
func load() -> void:
	history = EditorHistory.new()
	history.editor = self
	add_child(history)
	_create_history_controls()
	MusicPlayer.stream = SMWTheme.music_for(level.current_sub_area, true)
	MusicPlayer.play.call_deferred()
	
	level.add_child(grid)
	level.add_child(dark_overlay)
	level.playing.connect(_play)
	level.editing.connect(_edit)
	
	loaded.emit()


func _create_history_controls() -> void:
	_history_controls = HBoxContainer.new()
	_history_controls.name = "HistoryControls"
	add_child(_history_controls)
	_history_controls.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_history_controls.position += Vector2(-132, -66)
	for action in ["EDITOR_UNDO", "EDITOR_REDO"]:
		var button := Button.new()
		button.theme_type_variation = &"CoursebotLevelButton"
		button.name = "Undo" if action == "EDITOR_UNDO" else "Redo"
		button.text = tr(action)
		button.custom_minimum_size = Vector2(126, 48)
		button.focus_mode = Control.FOCUS_NONE
		_history_controls.add_child(button)
	_undo_button = _history_controls.get_node("Undo")
	_redo_button = _history_controls.get_node("Redo")
	_undo_button.tooltip_text = "Ctrl+Z"
	_redo_button.tooltip_text = "Ctrl+Y / Ctrl+Shift+Z"
	_undo_button.pressed.connect(history.undo)
	_redo_button.pressed.connect(history.redo)
	_update_history_controls()


func refresh_theme() -> void:
	var music := SMWTheme.music_for(level.current_sub_area, true)
	# Editor music has no night variant; a day/night toggle keeps it playing.
	if MusicPlayer.stream != music or not MusicPlayer.playing:
		music_offset = 0
		MusicPlayer.stream = music
		MusicPlayer.play()
	get_node("LeftPanel/LevelThemeBtn").queue_redraw()
	get_node("PaletteMenu/RingContainer/Control/PaletteRing").refresh_icons()
	for card in find_children("*", "BaseButton", true, false):
		if card is EditorCard and card.part != null:
			card.refresh_icon()


func _update_history_controls() -> void:
	if history == null:
		return
	_history_controls.visible = level.status == Level.Status.EDITING
	var available := part_interact and held_part == null and not _saving
	_undo_button.disabled = not available or not history.can_undo()
	_redo_button.disabled = not available or not history.can_redo()


func _process_placing(process_multiplaceables: bool) -> void:
	_last_mouse_pos = level.get_global_mouse_position()
	
	var selected = get_selected_part()
	if selected == null or not Input.is_action_pressed("place"):
		return
	if not part_interact or erasing != EraseMode.NONE or not has_focus():
		return
	# makes sure whether this method should place multiplaceable parts,
	# as multiplaceable and non-multiplaceable are handled in different places
	if selected.is_multiplaceable() != process_multiplaceables:
		return
	if held_part != null:
		return
	# Slopes may overlap terrain, but clicking an existing slope must reach its
	# body/endpoint input instead of creating another copy before physics picking.
	if hovered_part is SlopePart or (hovered_part is SemisolidPart and selected == SemisolidPart):
		return
	
	var grid_pos := Level.to_grid(_last_mouse_pos)
	var valid: bool = selected.is_variant_placeable(grid_pos, get_world_2d(),
			_part_defaults.get(selected, &"hammer" if selected == HammerBroPart else &"thwomp" if selected == ThwompPart else &"grrrol_small")) if selected in [HammerBroPart, ThwompPart, GrrrolPart] \
			else selected.is_placeable(grid_pos, get_world_2d())
	if not valid and selected in [CoinPart, MushroomPart, OneUpPart, FireFlowerPart, StarPart]:
		var candidate: Part = selected.create()
		var target := content_target(grid_pos, candidate)
		valid = target != null and target.content_id != ContainerBlockPart.content_for(candidate, target)
		candidate.free()
	if selected in [SlopePart, GentleSlopePart]:
		valid = valid and grid_pos.x >= 0 and grid_pos.y >= -27 and grid_pos.y <= -2 \
				and (grid_pos.x + (4 if selected == GentleSlopePart else 3)) * 16 <= level.width
	if selected == SemisolidPart:
		valid = grid_pos.x >= 0 and grid_pos.y >= -27 and grid_pos.y <= -3 and (grid_pos.x + 3) * 16 <= level.width
	if valid:
		history.begin_stroke("Paint" if process_multiplaceables else "Place")
		place(Level.to_grid(_last_mouse_pos))


func _play() -> void:
	if (held_part is SlopePart or held_part is SemisolidPart) and held_part.resizing:
		held_part.end_resize()
	history.end_stroke()
	part_interact = false
	%TopPanel.status = EditorPanel.Status.HIDDEN
	%LeftPanel.status = EditorPanel.Status.HIDDEN
	%RightPanel.status = EditorPanel.Status.HIDDEN
	grid.hide()
	dark_overlay.hide()


func _edit() -> void:
	MusicPlayer.stream = SMWTheme.music_for(level.current_sub_area, true)
	MusicPlayer.play(music_offset)
	
	part_interact = true
	%TopPanel.status = EditorPanel.Status.OPEN
	%LeftPanel.status = EditorPanel.Status.OPEN
	%RightPanel.status = EditorPanel.Status.OPEN
	grid.show()
	match part_type:
		PartType.SOUNDS:
			dark_overlay.show()


func _set_erasing(v: EraseMode) -> void:
	if v == erasing:
		return
	erasing = v
	if v == EraseMode.NONE:
		%EraseBG.hide()
		Cursor.set_to_player()
		Cursor.down = false
		erase_stopped.emit()
	else:
		%EraseBG.show()
		Cursor.type = Cursor.Type.ERASER
		Cursor.down = true
		erase_started.emit()


func _set_part_type(v: PartType) -> void:
	if v == part_type:
		return
	
	part_type = v
	match v:
		PartType.OBJECTS:
			dark_overlay.hide()
		PartType.SOUNDS:
			dark_overlay.show()
	
	part_type_changed.emit()
