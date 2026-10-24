extends "res://tests/scripts/port_test.gd"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var library := load("res://scripts/singletons/sprite_library.gd").new() as Node
	check(library.get_frames(&"spr_hammerbro_res").get_frame_count(&"default") == 0
			and library._frames_cache.is_empty(), "Pre-ready sprite lookup cached an empty animation")
	add_child(library)
	check(library.get_frames(&"spr_hammerbro_res").get_frame_count(&"default") == 4,
			"Early lookup prevented the manifest's real Bro frames loading")
	library.free()
	var level := await LevelActionBtn.prepare_level("res://tests/fixtures/port_slice.swe", Level.Status.EDITING)
	add_child(level)
	await ticks(20)
	var editor := level.editor
	var ring: PaletteRing = editor.get_node("PaletteMenu/RingContainer/Control/PaletteRing")
	ring.category = load("res://resources/palette/category_enemies.tres")
	ring.page_index = 1
	ring.choose(5)
	await ticks(20)
	var card: EditorCard
	for node in editor.get_node("%Cards").get_children():
		if node.part == HammerBroPart:
			card = node
	var icon: TextureRect = card.get_node("%Icon")
	var expected := editor.get_palette_icon(HammerBroPart)
	check(expected != null and icon.texture == expected, "Cold default Bro palette/card icon is missing")
	if expected == null:
		await finish("PALETTE_ICON_RESULT", level)
		return
	if "--capture-palette-icon" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		check_rendered(icon)
		editor.get_node("PaletteMenu").show()
		ring.set_process(false)
		ring.selected = 5
		await ticks(20)
		await RenderingServer.frame_post_draw
		var found := 0
		for node in ring.find_children("*", "TextureRect", true, false):
			if node.texture == expected and node.is_visible_in_tree():
				check_rendered(node)
				found += 1
		check(found >= 2, "Bro center/sector icons were not both drawn in the native palette")
		get_viewport().get_texture().get_image().save_png("res://.godot/porting-tests/slice_palette_icon.png")
		print("CAPTURE_RESULT ", "PASS" if failures.is_empty() else "FAIL")
	await finish("PALETTE_ICON_RESULT", level)


func check_rendered(icon: TextureRect) -> void:
	var expected := icon.texture.get_image()
	var rendered := get_viewport().get_texture().get_image()
	var factor := minf(icon.size.x / expected.get_width(), icon.size.y / expected.get_height())
	var offset := (icon.size - Vector2(expected.get_size()) * factor) / 2
	var matched := 0
	var count := 0
	for y in expected.get_height():
		for x in expected.get_width():
			var color := expected.get_pixel(x, y)
			if color.a < 0.99 or color.r + color.g + color.b < 0.2 or color.r + color.g + color.b > 2.9:
				continue
			var at := Vector2i(icon.get_global_transform_with_canvas() * (offset + (Vector2(x, y) + Vector2(0.5, 0.5)) * factor))
			count += 1
			var found := false
			# Ring sectors sit at fractional trigonometric coordinates. Permit
			# their one-screen-pixel nearest-sampling boundary, not an empty icon.
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var actual := rendered.get_pixelv(at + Vector2i(dx, dy))
					found = found or absf(actual.r - color.r) + absf(actual.g - color.g) + absf(actual.b - color.b) < 0.04
			if found:
				matched += 1
	check(count > 100 and matched > count * 0.8, "Bro icon texture exists but its actual clipped UI pixels are absent")
