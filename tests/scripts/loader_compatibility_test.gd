extends "res://tests/scripts/port_test.gd"
## Legacy/new key aliases, malformed metadata, unknown IDs and async IDs.

var _results: Dictionary = {}


func write_fixture(name: String, data: Dictionary) -> String:
	var path := "res://.godot/porting-tests/" + name + ".swe"
	DirAccess.make_dir_recursive_absolute("res://.godot/porting-tests")
	var b64 := Marshalls.utf8_to_base64(JSON.stringify(data)).to_utf8_buffer()
	var digest := Crypto.new().hmac_digest(HashingContext.HASH_SHA1,
			LevelProcessor.SWE_HMAC_KEY.to_utf8_buffer(), b64).hex_encode()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(b64)
	file.store_string(digest)
	file.close()
	return path


func load_async(key: String, path: String) -> void:
	_results[key] = await LevelProcessor.from_swe(path)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var original := LevelProcessor.decode_swe(FileAccess.get_file_as_bytes("res://tests/fixtures/port_slice.swe"))
	check(original.verified, "Generated legacy SWE signature is invalid")
	var data: Dictionary = original.data.duplicate(true)
	var wrapper: Dictionary = data.MAIN
	var settings: Dictionary = wrapper.AJUSTES[0]
	settings.apariencia = 1
	settings.entorno = "ghost"
	settings.cronometro = 125
	settings.etiqueta1 = Level.Tag.size() - 1
	wrapper.NIVEL.append({"object": "obj_future_unported_enemy", "x_pos": 600, "y_pos": 400})
	var legacy := write_fixture("legacy_aliases", data)
	var old: Level = await LevelProcessor.from_swe(legacy)
	check(old.game_style == Level.GameStyle.SMB3 and old.current_sub_area.level_theme == Level.LevelTheme.MANSION,
			"Legacy style/theme values were overridden")
	check(old.time == 125 and old.tag_1 == Level.Tag.NONE, "Legacy timer/tag wrap failed")
	old.free()

	var modern := {"S0": {"S1": [{
		"gamestyle": 3, "gametheme": "underwater", "timer": 240,
		"label_1": -1, "label_2": 2, "c_conditions": 0, "nightmode": false,
		"user": "new-format-test", "desc": "Modern SWE aliases", "start_y": 400,
	}], "S2": [{"xx": 128, "yy": 400, "i": 21}], "S4": [
		{"ID": "obj_coin_res", "xx": 144, "yy": 368},
		{"ID": "obj_goalgate", "xx": 800, "yy": 263},
	]}}
	var modern_path := write_fixture("modern_aliases", modern)
	var new: Level = await LevelProcessor.from_swe(modern_path)
	check(new.game_style == Level.GameStyle.NSMBU, "New game style alias was ignored")
	check(new.current_sub_area.level_theme == Level.LevelTheme.UNDERWATER and new.time == 240,
			"New theme/timer aliases were ignored")
	var parts := new.current_sub_area.get_parts()
	check(parts.get_node("EditorPlayer").position == Vector2(56, -48), "Course spawn ignored starting-ground height")
	check(parts.get_node("StartingGround").position.y == -32, "New start_y alias was lost")
	var ground_count := 0
	var goal_count := 0
	for part in parts.get_children():
		if part is GroundPart:
			ground_count += 1
			check(part.swe_frame == 21 and part.swe_atlas == Vector2(16, 0), "New ground atlas index was lost")
		if part is GoalPolePart:
			goal_count += 1
			check(part.position == Vector2(800, -169), "Goal coordinates were incorrectly grid-snapped")
	check(ground_count == 1 and goal_count == 1, "Explicit goal was dropped or duplicated")
	new.free()

	# Invalid scalar values should fall back safely instead of selecting a
	# different valid enum via truncation or failing on an atlas array index.
	var invalid: Dictionary = modern.duplicate(true)
	invalid.S0.S1[0].gamestyle = 1.5
	invalid.S0.S1[0].gametheme = "unknown_theme"
	invalid.S0.S1[0].timer = -500
	invalid.S0.S2[0].i = 9999
	var invalid_level: Level = await LevelProcessor.from_swe(write_fixture("invalid_metadata", invalid))
	check(invalid_level.game_style == Level.GameStyle.SMW and invalid_level.time == 300,
			"Invalid style/timer did not use safe defaults")
	check(invalid_level.current_sub_area.level_theme == Level.LevelTheme.OVERWORLD,
			"Invalid theme did not retain its default")
	invalid_level.free()
	var empty: Level = await LevelProcessor.from_swe(write_fixture("empty_settings", {"MAIN": {
		"AJUSTES": [], "SUELO": [], "NIVEL": [],
	}}))
	check(empty == null, "Empty settings should fail without an array bounds error")

	load_async.call("legacy", legacy)
	load_async.call("modern", modern_path)
	var deadline := Time.get_ticks_msec() + 5000
	while _results.size() < 2 and Time.get_ticks_msec() < deadline:
		await ticks(1)
		# --fixed-fps can simulate thousands of frames before the worker gets
		# an OS time slice. Bound this asynchronous check by wall time.
		OS.delay_msec(1)
	check(_results.size() == 2, "Concurrent requests did not both finish")
	if _results.size() == 2:
		check(_results.legacy.file_path == legacy and _results.modern.file_path == modern_path,
				"Concurrent requests returned each other's levels")
		check(_results.legacy != _results.modern, "Concurrent requests returned the same Level")
	for level: Level in _results.values():
		level.free()
	_results.clear()
	await finish("LOADER_RESULT")
