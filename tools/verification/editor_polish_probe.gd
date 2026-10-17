extends Node
## Native GUI regression and render checks for the owner's visual corrections.
var editor: MakerEditor
var checks: int = 0
var failures: Array[String] = []
var capture: bool = false
var document_before: Dictionary
var sharpness: Dictionary = {}
var evidence_prefix: String = "sharp-ui"
var vector_rid: RID
var vector_resolution: Array[Dictionary] = []
var rendering_before: Dictionary

func _ready() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-prefix="):
			evidence_prefix = argument.trim_prefix("--evidence-prefix=")
	document_before = LevelManager.level_data.duplicate(true)
	rendering_before = {"msaa": get_window().msaa_2d, "oversampling": get_window().oversampling_override}
	call_deferred("_run")

func _run() -> void:
	editor = load("res://src/editor/editor.tscn").instantiate() as MakerEditor
	add_child(editor)
	await _frames()
	_check(not editor.has_node("%InfoPanel") and not editor.has_node("%ToolBubble"), "Removed explanatory placeholder panels and erase bubble")
	_check(TranslationServer.get_locale() == "en_US", "UI uses English as requested")
	_check(editor.get_theme_font("font").get_base_font().resource_path.begins_with("res://fonts/"), "UI primary font comes from local fonts")
	_check(editor.get_theme_font("font").get_base_font().resource_path == "res://fonts/MARIOMAKER.otf", "All UI text uses the local Mario Maker font")
	_check(not editor.get_theme_font("font").get_base_font().allow_system_fallback, "No default system font fallback")
	_check(editor.get_theme_font("font", "MakerPaletteTitle").resource_path == "res://fonts/MARIOMAKER.otf", "Palette title uses local Mario Maker font")
	_check(editor.maker_viewport.world.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "World explicitly uses nearest sampling")
	_check(editor.maker_viewport.get_node("SubViewport").canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST, "SubViewport default is nearest")
	_check(PaletteWheel.SLOT_COUNT == 10, "Reference palette has ten sectors")
	_check_no_tooltips(editor)
	_art_node_checks()
	var ui_font: Font = editor.get_theme_font("font")
	for label: Label in [editor.get_node("%TimeButton").get_node("Value"), editor.get_node("%PlayButton").get_node("Caption"), editor.get_node("%SelectButton").get_node("Caption")]:
		_check(label.get_theme_font("font") == ui_font, "Timer and captions use the same effective font as the UI")
		_check(ui_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x <= label.size.x, "English label fits its saved width")
	_check(editor.get_node("%PlayButton").get_node("Caption").text == "Play", "Play caption is English in the saved scene too")
	_check(not editor.get_node("%SelectButton").has_node("KeyBadge"), "Select shortcut badge removed")
	var svg_view: TextureRect = editor.get_node("%EraseButton").get_node("ArtView")
	svg_view.draw.connect(func() -> void: vector_rid = (svg_view.texture as DPITexture).get_scaled_rid())
	var cap_height: float = editor.get_node("%PaletteItems/fire_flower/CapView").size.y
	for part: MakerArtButton in editor.get_node("%PaletteItems").get_children():
		_check(is_equal_approx(part.get_node("CapView").size.y, cap_height), "Cap height matches the saved fire flower reference")
		_check(is_equal_approx(part.get_node("CapView").position.y, -8), "Owner's CapView y=-8 preserved")
	var dimensions_to_check: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080)]
	if "--large-windows" in OS.get_cmdline_user_args():
		dimensions_to_check.append_array([Vector2i(2560, 1440), Vector2i(3840, 2160)])
	for dimensions: Vector2i in dimensions_to_check:
		get_window().size = dimensions
		await _frames()
		if capture:
			svg_view.queue_redraw()
			await RenderingServer.frame_post_draw
			var raster: Image = RenderingServer.texture_2d_get(vector_rid)
			_check(raster != null, "SVG raster readable after drawing")
			if raster != null:
				vector_resolution.append({"window": dimensions, "svg_raster": raster.get_size(), "display": svg_view.get_global_rect().size})
				_check(raster.get_width() >= svg_view.get_global_rect().size.x - 2 and raster.get_height() >= svg_view.get_global_rect().size.y - 2, "SVG raster has enough pixels for displayed size")
		var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(dimensions))
		_check(editor.maker_viewport.get_global_rect() == screen, "Canvas fills window")
		for section: Control in [editor.get_node("ReferenceUI/TopBar"), editor.get_node("ReferenceUI/LeftBar"), editor.get_node("ReferenceUI/RightBar"), editor.get_node("%PlayButton")]:
			_check(screen.grow(0.01).encloses(section.get_global_rect()), "Toolbar %s fits %s" % [section.name, dimensions])
		for part: MakerArtButton in editor.get_node("%PaletteItems").get_children():
			var rect: Rect2 = part.artwork_rect()
			_check(rect.position.y >= part.size.x / 11.0 and rect.end.y <= part.size.y * 19.0 / 23.0, "Art safely inset above the card shadow")
			_check(rect.position.x > 0 and rect.end.x < part.size.x, "Art safely inset from card sides")
		await _motion(editor.get_node("%MenuButton").get_global_rect().get_center())
		_check(editor.get_node("%MenuButton").pointer_hovered, "Menu hover enables the four reference corners")
		_check(editor.maker_viewport.world.hovered_cell.x == -1, "Toolbar hover hides canvas preview")
		await _screenshot("editor-%dx%d" % [dimensions.x, dimensions.y])
		editor.state.select_object("smm.item.coin")
		editor._toggle_panel(EditorState.PanelKind.PALETTE)
		await _frames()
		_check(not editor.reference_ui.visible and editor.maker_viewport.input_blocked, "Full-screen palette hides toolbars and blocks canvas")
		_check(screen.encloses(editor.wheel.get_global_rect()), "Reference wheel fits %s" % dimensions)
		_check(editor.wheel.entries.size() == 10 and editor.wheel.entries[9]["icon"] == "yoshi_egg", "First item page follows reference icon order")
		for button: Button in editor.category_buttons:
			_check(screen.encloses(button.get_global_rect()), "Category header fits window")
			_check(is_equal_approx(button.size.x, 600 if button.button_pressed else 108), "Selected category becomes a pill")
		await _motion(Vector2(20, 200))
		await _screenshot("wheel-%dx%d" % [dimensions.x, dimensions.y])
		if capture:
			await _check_ring_images()
		editor.state.close_panel()
		await _frames()
	await _sharp_background()
	await _hover_visual_checks()
	get_window().size = Vector2i(1280, 720)
	await _frames()
	await _palette_checks()
	await _canvas_checks()
	await _keyboard_checks()
	await _fallback_checks()
	_check(LevelManager.level_data == document_before, "UI never writes level data")
	_check(editor.maker_viewport.world.get_child_count() == 1, "No live gameplay actors in editor")
	editor.queue_free()
	await _frames()
	_check(get_window().msaa_2d == rendering_before["msaa"], "Leaving the editor restores previous UI antialiasing")
	_check(is_equal_approx(get_window().oversampling_override, rendering_before["oversampling"]), "Leaving the editor restores previous SVG oversampling")
	for failure: String in failures:
		push_error("EDITOR_POLISH: " + failure)
	print("EDITOR_POLISH checks=%d failures=%d" % [checks, failures.size()])
	var file: FileAccess = FileAccess.open("res://local_debug_output/editor-%s-verification.json" % evidence_prefix, FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "capture": capture, "background": sharpness, "vector_resolution": vector_resolution}, "\t"))
	get_tree().quit(0 if failures.is_empty() else 1)

func _art_node_checks() -> void:
	for button: MakerArtButton in editor.get_node("%PaletteItems").get_children():
		var art: TextureRect = button.get_node("ArtView")
		var cap: TextureRect = button.get_node("CapView")
		_check(art.texture == button.art and art.mouse_filter == Control.MOUSE_FILTER_IGNORE, "ArtView owns texture and lets the button receive input")
		_check(cap.texture != null and cap.mouse_filter == Control.MOUSE_FILTER_IGNORE, "CapView owns the adjustable cap")
	var custom: TextureRect = editor.get_node("%ThemeButton").get_node("ArtView")
	_check(custom.position.is_equal_approx(Vector2(5.745, 2.57)) and custom.size.is_equal_approx(Vector2(82, 82)), "Owner's ArtView geometry preserved")
	_check(custom.material is ShaderMaterial and is_equal_approx(custom.material.get_shader_parameter("radius"), 0.08), "Owner's rounded shader preserved")
	var part: MakerArtButton = editor.get_node("%PaletteItems").get_child(0)
	var view: TextureRect = part.get_node("ArtView")
	var before: Vector2 = view.position
	view.position += Vector2(2, 3)
	part.art = part.art
	_check(view.position.is_equal_approx(before + Vector2(2, 3)), "Texture synchronization never overwrites manually edited layout")
	view.position = before
	for button: MakerArtButton in editor.category_buttons:
		_check(button.has_node("ArtView") and not button.hover_corners, "Category art uses a child without corner feedback")
	for name: String in ["PreviousPage", "NextPage"]:
		_check(not editor.get_node("%" + name).hover_corners, "Page switch arrows have no corner feedback")

func _hover_visual_checks() -> void:
	editor.state.select_object("smm.block.hard")
	editor._toggle_panel(EditorState.PanelKind.PALETTE)
	await _frames()
	var slot: int = 3
	for dimensions: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(960, 540)]:
		get_window().size = dimensions
		await _frames()
		await _motion(editor.wheel.get_global_transform() * editor.wheel.slot_center(slot))
		_check(editor.wheel.hovered_slot == slot, "Sector hover stays correct after window resize")
		await _screenshot("wheel-sector-%dx%d" % [dimensions.x, dimensions.y])
		if capture:
			await RenderingServer.frame_post_draw
			var actual: Image = get_viewport().get_texture().get_image()
			var sample: Vector2 = editor.wheel.size * 0.5 + Vector2.from_angle(PaletteWheel.START_ANGLE + slot * PaletteWheel.STEP) * editor.wheel._radius() * 0.60
			var screen: Vector2 = editor.wheel.get_global_transform() * sample
			var color: Color = actual.get_pixel(roundi(screen.x), roundi(screen.y))
			var expected: Color = PaletteWheel.CATEGORY_COLORS["terrain"]
			_check(Vector3(color.r, color.g, color.b).distance_to(Vector3(expected.r, expected.g, expected.b)) < 0.02, "Rendered hovered sector fills with the same color as the center")
	await _motion(editor.get_node("%NextPage").get_global_rect().get_center())
	_check(editor.wheel.hovered_slot == -1, "Leaving the ring clears its sector highlight")
	await _screenshot("page-hover-960x540")
	editor.state.close_panel()

func _check_no_tooltips(node: Node) -> void:
	if node is Control:
		_check(node.tooltip_text.is_empty(), "No generic tooltip on " + String(node.name))
	for child: Node in node.get_children():
		_check_no_tooltips(child)

func _sharp_background() -> void:
	if not capture:
		return
	editor.state.set_grid_visible(false)
	editor.maker_viewport.suspend_pointer()
	await _frames()
	await RenderingServer.frame_post_draw
	var rendered: Image = editor.maker_viewport.get_node("SubViewport").get_texture().get_image()
	var original: Image = load("res://textures/smw/background/background.png").get_image()
	var largest: float = 0
	var samples: int = 0
	for y: int in range(40, 1000, 19):
		for x: int in range(40, 1850, 23):
			var world: Vector2 = editor.maker_viewport.screen_to_world(Vector2(x + 0.5, y + 0.5))
			var source: Color = original.get_pixel(posmod(floori(world.x) + 128, original.get_width()), floori(world.y))
			var actual: Color = rendered.get_pixel(x, y)
			largest = maxf(largest, maxf(absf(source.r - actual.r), maxf(absf(source.g - actual.g), absf(source.b - actual.b))))
			samples += 1
	sharpness = {"samples": samples, "max_rgb_difference": largest, "tolerance": 0.012}
	_check(largest <= 0.012, "Background render preserves the nearest source texel without linear blending")
	rendered.save_png("res://local_debug_output/%s-background-1920x1080.png" % evidence_prefix)
	editor.state.set_grid_visible(true)

func _check_ring_images() -> void:
	await RenderingServer.frame_post_draw
	var rendered: Image = get_viewport().get_texture().get_image()
	var factor: float = editor.palette_panel.scale.x
	for slot: int in 10:
		var center: Vector2 = editor.wheel.get_global_transform() * editor.wheel.slot_center(slot)
		var extent: int = roundi(48 * factor)
		var dark_pixels: int = 0
		for y: int in range(-extent, extent):
			for x: int in range(-extent, extent):
				var color: Color = rendered.get_pixel(roundi(center.x) + x, roundi(center.y) + y)
				if color.r < 0.4 and color.g < 0.4 and color.b < 0.4:
					dark_pixels += 1
		_check(dark_pixels > 20, "Actual ring image is rendered, including unregistered parts: " + String(editor.wheel.entries[slot]["icon"]))

func _palette_checks() -> void:
	await _click(editor.get_node("%PaletteButton").get_global_rect().get_center())
	_check(editor.overlay.visible, "Palette button opens full-screen palette")
	for category: String in MakerEditor.CATEGORIES:
		await _click(editor.category_buttons[MakerEditor.CATEGORIES.find(category)].get_global_rect().get_center())
		_check(editor.wheel.category == category, "Category click changes wheel")
		_check(editor.wheel.slot_at(editor.wheel.size * 0.5) == -1, "Center dead zone")
		var before_id: String = editor.state.object_id
		await _click(editor.wheel.get_global_rect().get_center())
		_check(editor.state.object_id == before_id and editor.overlay.visible, "Center consumes click without selection")
		for slot: int in editor.wheel.entries.size():
			var point: Vector2 = editor.wheel.get_global_transform() * editor.wheel.slot_center(slot)
			var object_id: String = editor.wheel.entries[slot]["id"]
			await _motion(point)
			_check(editor.wheel.hovered_slot == slot, "Hover hits the correct scaled sector")
			await _click(point)
			if object_id.is_empty():
				_check(editor.state.object_id == before_id and editor.overlay.visible, "Unregistered art stays inactive")
			else:
				_check(editor.state.object_id == object_id and editor.state.tool == EditorState.Tool.DRAW and not editor.overlay.visible, "Registered slot selects and closes")
				before_id = object_id
				editor._toggle_panel(EditorState.PanelKind.PALETTE)
				editor._choose_category(category)
				await _frames()
		var before_page: int = editor.wheel.page
		await _click(editor.get_node("%NextPage").get_global_rect().get_center())
		_check(editor.wheel.page == posmod(before_page + 1, editor.wheel.page_count()), "Next arrow navigates pages")
		await _click(editor.get_node("%PreviousPage").get_global_rect().get_center())
		_check(editor.wheel.page == before_page, "Previous arrow restores page")
		if editor.wheel.page_count() > 1:
			editor.wheel.turn_page(1)
			await _frames()
			var before_empty: String = editor.state.object_id
			var empty: Vector2 = editor.wheel.get_global_transform() * editor.wheel.slot_center(9)
			_check(editor.wheel.slot_at(editor.wheel.slot_center(9)) == -1, "Empty sector stays inactive")
			await _click(empty)
			_check(editor.state.object_id == before_empty and editor.overlay.visible, "Empty click stays inside modal")
	await _click(editor.get_node("%CloseButton").get_global_rect().get_center())
	_check(not editor.overlay.visible, "Close tile closes palette")
	for button: Button in [editor.get_node("%CoursebotButton"), editor.get_node("%ThemeButton")]:
		await _click(button.get_global_rect().get_center())
		_check(editor.state.panel == EditorState.PanelKind.NONE and button.disabled, "Unfinished entry has no explanatory preview")
	await _key(KEY_TAB)
	await _click(Vector2(20, 200))
	_check(not editor.overlay.visible, "Outside click closes palette")
	for tool: int in editor.tool_buttons.size():
		await _click(editor.tool_buttons[tool].get_global_rect().get_center())
		_check(editor.state.tool == tool and editor.tool_buttons[tool].button_pressed, "Tool button updates state")
	await _click(editor.get_node("%MenuButton").get_global_rect().get_center())
	var grid_before: bool = editor.state.grid_visible
	await _click(editor.grid_button.get_global_rect().get_center())
	_check(editor.state.grid_visible != grid_before, "Real menu control changes grid")
	var rect: Rect2 = editor.position_slider.get_global_rect()
	await _click(rect.position + rect.size * Vector2(0.6, 0.5))
	_check(is_equal_approx(editor.state.view_center.x, editor.position_slider.value) and editor.state.view_center.x > 1000, "Real menu slider pans without input leakage")
	editor.state.close_panel()
	editor.state.set_grid_visible(true)

func _canvas_checks() -> void:
	var view: MakerViewport = editor.maker_viewport
	view._set_view(Vector2(900, 216), 2.0)
	await _frames()
	var local_point: Vector2 = view.size * 0.5 + Vector2(24, 12)
	await _motion(view.global_position + local_point)
	_check(view.world.hovered_cell == view.cell_at(local_point), "GUI hover follows screen-to-grid conversion")
	var real_world: Vector2 = view.world.get_canvas_transform().affine_inverse() * local_point
	_check(real_world.is_equal_approx(view.screen_to_world(local_point)), "Coordinate math matches actual Camera2D canvas transform")
	var anchor: Vector2 = view.screen_to_world(local_point)
	await _mouse_button(view.global_position + local_point, MOUSE_BUTTON_WHEEL_UP, true)
	_check(is_equal_approx(editor.state.zoom, 2.5), "Wheel action zooms in")
	_check(view.screen_to_world(local_point).is_equal_approx(anchor), "Zoom preserves cursor world anchor away from bounds")
	view._zoom_at(local_point, 99)
	_check(is_equal_approx(editor.state.zoom, 4), "Zoom upper bound")
	view._zoom_at(local_point, 0.01)
	_check(is_equal_approx(editor.state.zoom, 1), "Zoom lower bound")
	view._set_view(Vector2(-1000, 1000), 2)
	_check(editor.state.view_center.x + 0.001 >= view.size.x * 0.5 / view.view_scale, "Camera clamps at left bound")
	_check(editor.state.view_center.y <= 432 - view.size.y * 0.5 / view.view_scale, "Camera clamps at bottom bound")
	view._set_view(Vector2(900, 216), 2)
	await _motion(view.global_position + local_point)
	await _mouse_button(view.global_position + local_point, MOUSE_BUTTON_MIDDLE, true)
	var old_center: Vector2 = editor.state.view_center
	await _motion(view.global_position + local_point + Vector2(48, 0), Vector2(48, 0), MOUSE_BUTTON_MASK_MIDDLE)
	_check(is_equal_approx(editor.state.view_center.x, old_center.x - 48 / view.view_scale), "Middle drag pans in world units")
	await _mouse_button(Vector2(10, 10), MOUSE_BUTTON_MIDDLE, false)
	await _motion(Vector2(10, 10))
	_check(not view._dragging and view.world.hovered_cell == Vector2i(-1, -1), "Leaving canvas cancels drag and hides hover")
	view.pan_horizontal(1200)
	_check(is_equal_approx(editor.position_slider.value, 1200), "Slider follows camera center")
	editor.position_slider.value = 1300
	_check(is_equal_approx(editor.state.view_center.x, 1300), "Slider drives camera center without feedback loop")
	await _motion(view.global_position + view.size * 0.5)
	editor._toggle_panel(EditorState.PanelKind.PALETTE)
	await _frames()
	var modal_center: Vector2 = editor.state.view_center
	var modal_zoom: float = editor.state.zoom
	await _mouse_button(editor.wheel.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP, true)
	_check(editor.state.view_center == modal_center and editor.state.zoom == modal_zoom, "Wheel input cannot pass through modal to canvas")
	_check(view.world.hovered_cell == Vector2i(-1, -1), "Modal hides canvas preview")
	editor.state.close_panel()
	view._set_view(Vector2(900, 216), 2)
	editor.state.select_tool(EditorState.Tool.DRAW)
	await _motion(view.global_position + view.size * 0.5)
	await _screenshot("editor-hover-1280x720")


func _keyboard_checks() -> void:
	await _key(KEY_B)
	_check(editor.state.tool == EditorState.Tool.DRAW, "B selects draw")
	await _key(KEY_E)
	_check(editor.state.tool == EditorState.Tool.ERASE, "E selects erase")
	await _key(KEY_V)
	_check(editor.state.tool == EditorState.Tool.SELECT, "V selects selection")
	var grid_before: bool = editor.state.grid_visible
	await _key(KEY_G)
	_check(editor.state.grid_visible != grid_before and editor.grid_button.button_pressed == editor.state.grid_visible, "G synchronizes grid state and button")
	editor.get_node("%DrawButton").grab_focus()
	await _key(KEY_TAB)
	_check(editor.state.panel == EditorState.PanelKind.PALETTE, "Tab opens menu even when a button has focus")
	await _key(KEY_B)
	_check(editor.state.tool == EditorState.Tool.SELECT, "Modal blocks tool shortcuts")
	await _key(KEY_TAB)
	_check(editor.state.panel == EditorState.PanelKind.NONE, "Tab toggles modal closed")
	await _motion(editor.maker_viewport.get_global_rect().get_center())
	await _mouse_button(editor.maker_viewport.get_global_rect().get_center(), MOUSE_BUTTON_MIDDLE, true)
	_check(editor.maker_viewport._dragging, "Drag starts before focus-out check")
	get_window().focus_exited.emit()
	_check(not editor.maker_viewport._dragging, "Window focus loss cancels drag")
	await _mouse_button(editor.maker_viewport.get_global_rect().get_center(), MOUSE_BUTTON_MIDDLE, false)
	var field: LineEdit = LineEdit.new()
	field.position = Vector2(400, 100)
	field.size = Vector2(200, 40)
	editor.add_child(field)
	field.grab_focus()
	await _key(KEY_E)
	_check(editor.state.tool == EditorState.Tool.SELECT, "Text focus suppresses tool shortcut")
	await _key(KEY_G)
	_check(editor.state.grid_visible != grid_before, "Text focus suppresses grid shortcut")
	field.release_focus()
	field.queue_free()
	await _frames()


func _key(key: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame


func _fallback_checks() -> void:
	var missing_catalog: EditorCatalog = EditorCatalog.new()
	missing_catalog._manifest_loaded = true
	missing_catalog._manifest = {
		"groups": {"goomba": {"animations": {"walk": {"asset": "missing", "frames": [0]}}}},
		"assets": {"missing": {"metadata_state": "verified", "texture_path": "res://textures/does_not_exist.png"}},
	}
	_check(missing_catalog.preview_for("smm.enemy.goomba") == null, "Missing PNG returns a static placeholder without loading a broken resource")
	_check(missing_catalog.label_for("smm.enemy.goomba").contains("SMB1"), "Placeholder keeps the Goomba art distinction")
	var fallback_editor: MakerEditor = load("res://src/editor/editor.tscn").instantiate() as MakerEditor
	for definition: Dictionary in Registry.get_by_style(&"smw"):
		fallback_editor.catalog._icons[String(definition["id"])] = null
		fallback_editor.catalog._previews[String(definition["id"])] = null
	get_window().size = Vector2i(960, 540)
	add_child(fallback_editor)
	await _frames()
	for button: Button in fallback_editor._palette_buttons.values():
		_check((button as MakerArtButton).art == null and button.text.is_empty() and Rect2(Vector2.ZERO, Vector2(960, 540)).encloses(button.get_global_rect()), "Missing art stays blank with intact hit area as requested")
	fallback_editor.queue_free()
	await _frames()


func _motion(point: Vector2, relative: Vector2 = Vector2.ZERO, mask: int = 0) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	event.button_mask = mask
	Input.parse_input_event(event)
	await get_tree().process_frame


func _mouse_button(point: Vector2, index: MouseButton, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	await get_tree().process_frame


func _click(point: Vector2) -> void:
	await _motion(point)
	await _mouse_button(point, MOUSE_BUTTON_LEFT, true)
	await _mouse_button(point, MOUSE_BUTTON_LEFT, false)
	await _frames()


func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _screenshot(name: String) -> void:
	if not capture:
		return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var result: Error = image.save_png("res://local_debug_output/%s-%s.png" % [evidence_prefix, name])
	_check(result == OK, "Screenshot saved: " + name)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
