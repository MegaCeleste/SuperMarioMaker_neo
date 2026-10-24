extends "res://tests/scripts/port_test.gd"
## Snapshot -> staged save -> reopen, preserving unknown data and edits.

const DIRECTORY := "res://.godot/porting-tests/"
var _pending: Dictionary = {}


func write_data(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(LevelProcessor.encode_swe(data))
	file.close()


func counts(level: Level) -> Dictionary:
	var result: Dictionary = {}
	for part in level.current_sub_area.get_parts().get_children():
		var key: String = part.get_script().get_global_name()
		result[key] = int(result.get(key, 0)) + 1
	return result


func async_save(key: String, level: Level, path: String) -> void:
	_pending[key] = await LevelProcessor.save_swe(level, path)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var fixture := LevelProcessor.decode_swe(FileAccess.get_file_as_bytes("res://tests/fixtures/port_slice.swe"))
	var raw: Dictionary = fixture.data.duplicate(true)
	raw.future_root = {"unicode": "保留原始数据", "values": [1, true, "text"]}
	raw.MAIN.AJUSTES[0].future_setting = {"nested": "retained"}
	raw.MAIN.TUBERIAS = [{"object": "future_pipe", "pair": 3}]
	var unknown := {"object": "obj_future_unported", "x_pos": 333, "y_pos": 321, "custom": [3, 4]}
	raw.MAIN.NIVEL.insert(2, unknown)
	raw.MAIN.NIVEL[3].future_variant = {"keep": true}
	# JSON numbers load as floats in Godot; compare normalized JSON values.
	raw = JSON.parse_string(JSON.stringify(raw))
	unknown = raw.MAIN.NIVEL[2]
	var source := DIRECTORY + "roundtrip_source.swe"
	write_data(source, raw)
	var original_bytes := FileAccess.get_file_as_bytes(source)
	var level: Level = await LevelProcessor.from_swe(source)
	check(level != null, "Round-trip source did not load")
	if level == null:
		await finish("SWE_ROUNDTRIP_RESULT")
		return
	level.author = "保存测试"
	level.description = "Round-trip after moving and deleting parts"
	level.time = 215
	level.width = 1024
	level.tag_1 = Level.Tag.NONE
	level.tag_2 = Level.Tag.LINK
	var parts := level.current_sub_area.get_parts()
	var removed := false
	for part in parts.get_children():
		if part is CoinPart:
			if not removed:
				parts.remove_child(part)
				part.free()
				removed = true
			else:
				part.position = Vector2(176, -48)
			continue
		if part is GoalPolePart:
			part.position = Vector2(864, -153)
	parts.get_node("EditorPlayer").position = Vector2(48, -32)
	var added := GoombaPart.create()
	added.position = Vector2(720, -32)
	level.current_sub_area.add_part(added)
	var path := DIRECTORY + "roundtrip_saved.swe"
	var saved: Dictionary = await LevelProcessor.save_swe(level, path)
	check(saved.error == OK and level.file_path == path, "Save API failed: %s" % saved)
	check(FileAccess.get_file_as_bytes(source) == original_bytes, "Save As changed the source file")
	var decoded := LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(path))
	check(decoded.verified, "Saved SWE HMAC does not match its base64 payload")
	for entry in decoded.data.MAIN.NIVEL:
		check(entry.get("object", "") != "obj_mariostart", "Editor cursor was serialized as OpenWE's intro overlay")
	check(decoded.data.future_root == raw.future_root and decoded.data.MAIN.TUBERIAS == raw.MAIN.TUBERIAS,
			"Saving discarded an unported root/section")
	check(decoded.data.MAIN.AJUSTES[0].future_setting == raw.MAIN.AJUSTES[0].future_setting,
			"Saving discarded an unknown setting")
	check(decoded.data.MAIN.NIVEL[1] == unknown, "Unknown object data/order did not survive a neighbouring deletion")
	var reopened: Level = await LevelProcessor.from_swe(path)
	check(counts(reopened) == counts(level), "Part types/counts changed on save/reopen")
	check(reopened.author == "保存测试" and reopened.time == 215 and reopened.width == 1024,
			"Saved scalar metadata did not round-trip")
	check(reopened.tag_1 == Level.Tag.NONE and reopened.tag_2 == Level.Tag.LINK,
			"Tags changed on save/reopen")
	check(reopened.current_sub_area.get_parts().get_node("EditorPlayer").position == Vector2(56, -32),
			"Reopened course spawn did not use starting ground")
	reopened.free()

	# Repeat after an earlier deletion shifted source indices. This catches
	# stale binding indices overwriting another row on the second save.
	parts.remove_child(added)
	added.free()
	var second_coin := CoinPart.create()
	second_coin.position = Vector2(496, -48)
	level.current_sub_area.add_part(second_coin)
	saved = await LevelProcessor.save_swe(level, path)
	check(saved.error == OK, "Replacing an existing level failed")
	reopened = await LevelProcessor.from_swe(path)
	check(counts(reopened) == counts(level), "Repeated save reused stale source indices")
	decoded = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(path))
	check(decoded.data.MAIN.NIVEL[1] == unknown, "Repeated save changed the unknown object")
	var retained_variant := false
	for entry in decoded.data.MAIN.NIVEL:
		if entry.get("future_variant", {}) == {"keep": true}:
			retained_variant = true
	check(retained_variant, "Moving a supported object discarded its unknown fields")
	reopened.free()

	var bytes_before := FileAccess.get_file_as_bytes(path)
	var metadata: Level = await LevelProcessor.from_swe(path, true)
	var rejected: Dictionary = await LevelProcessor.save_swe(metadata, path)
	check(rejected.error != OK and FileAccess.get_file_as_bytes(path) == bytes_before,
			"Metadata-only save overwrote the complete level")
	metadata.free()
	var unsupported := Part.create()
	level.current_sub_area.add_part(unsupported)
	rejected = await LevelProcessor.save_swe(level, path)
	check(rejected.error != OK and FileAccess.get_file_as_bytes(path) == bytes_before,
			"Unsupported Part was silently dropped during overwrite")
	parts.remove_child(unsupported)
	unsupported.free()
	var missing := DIRECTORY + "not-a-directory-%d/no-save.swe" % OS.get_process_id()
	rejected = await LevelProcessor.save_swe(level, missing)
	check(rejected.error != OK and level.file_path == path and FileAccess.get_file_as_bytes(path) == bytes_before,
			"Failed write changed the current path or existing file")

	async_save.call("first", level, DIRECTORY + "concurrent_first.swe")
	async_save.call("second", level, missing)
	var deadline := Time.get_ticks_msec() + 5000
	while _pending.size() < 2 and Time.get_ticks_msec() < deadline:
		await ticks(1)
		OS.delay_msec(1)
	check(_pending.size() == 2, "Concurrent saves did not both finish")
	if _pending.size() == 2:
		check(_pending.first.error == OK and _pending.second.error != OK,
				"Concurrent save responses were mixed up")
		check(level.file_path == DIRECTORY + "concurrent_first.swe", "Failed concurrent save changed the successful path")
	level.free()

	var modern := {"S0": {"S1": [{"gamestyle": 1, "gametheme": "ghost", "timer": 125,
		"user": "modern", "desc": "Modern save", "nightmode": false, "start_y": 400}],
		"S2": [{"xx": 128, "yy": 400, "i": 21}], "S4": [
			{"ID": "obj_coin_res", "xx": 144, "yy": 368},
			{"ID": "obj_goalgate", "xx": 800, "yy": 263}], "S9": ["unported section"]}}
	var modern_source := DIRECTORY + "modern_roundtrip_source.swe"
	write_data(modern_source, modern)
	var modern_level: Level = await LevelProcessor.from_swe(modern_source)
	var modern_saved := DIRECTORY + "modern_roundtrip_saved.swe"
	saved = await LevelProcessor.save_swe(modern_level, modern_saved)
	check(saved.error == OK, "Saving a modern SWE failed")
	decoded = LevelProcessor.decode_swe(FileAccess.get_file_as_bytes(modern_saved))
	check(decoded.verified and decoded.data.has("S0") and not decoded.data.has("MAIN"), "Modern wrapper/signature changed")
	check(decoded.data.S0.S1[0].gamestyle == 1 and decoded.data.S0.S1[0].gametheme == "ghost" \
			and decoded.data.S0.S9 == ["unported section"], "Modern metadata or unknown section was lost")
	reopened = await LevelProcessor.from_swe(modern_saved)
	check(counts(reopened) == counts(modern_level), "Modern SWE Parts did not round-trip")
	for part in reopened.current_sub_area.get_parts().get_children():
		if part is GoalPolePart:
			check(part.position == Vector2(800, -169), "Modern off-grid goal position changed")
	modern_level.free()
	reopened.free()
	var incomplete := DIRECTORY + "incomplete_source.swe"
	write_data(incomplete, {"MAIN": {"AJUSTES": [{}], "SUELO": []}})
	var incomplete_level: Level = await LevelProcessor.from_swe(incomplete)
	rejected = await LevelProcessor.save_swe(incomplete_level, path)
	check(rejected.error != OK and FileAccess.get_file_as_bytes(path) == bytes_before,
			"Incomplete loading allowed a lossy overwrite")
	incomplete_level.free()
	await finish("SWE_ROUNDTRIP_RESULT")
