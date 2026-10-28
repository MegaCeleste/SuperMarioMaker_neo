extends Node
## Handles [Level] serialization and building with multi-threading.

enum _Command {
	EXIT,
	LOAD,
	SAVE,
	BUILD,
}

signal _done(id: int, data: Variant)

const SWE_HMAC_KEY = "2559F35097-2021"
const SWE_GROUND_FRAME_TABLE = [
	Vector2(80, 144),
	Vector2(0, 96),
	Vector2(80, 112),
	Vector2(80, 96),
	Vector2(0, 176),
	Vector2(0, 112),
	Vector2(64, 112),
	Vector2(64, 176),
	Vector2(0, 80),
	Vector2(0, 0),
	Vector2(80, 0),
	Vector2(80, 80),
	Vector2(0, 128),
	Vector2(16, 112),
	Vector2(64, 128),
	Vector2(16, 176),
	Vector2(0, 160),
	Vector2(0, 144),
	Vector2(0, 16),
	Vector2(32, 112),
	Vector2(48, 112),
	Vector2(16, 0),
	Vector2(64, 144),
	Vector2(64, 160),
	Vector2(80, 16),
	Vector2(32, 176),
	Vector2(48, 176),
	Vector2(16, 80),
	Vector2(16, 128),
	Vector2(64, 32),
	Vector2(64, 48),
	Vector2(48, 48),
	Vector2(48, 32),
	Vector2(32, 128),
	Vector2(16, 144),
	Vector2(48, 128),
	Vector2(16, 160),
	Vector2(64, 64),
	Vector2(48, 64),
	Vector2(32, 144),
	Vector2(32, 160),
	Vector2(48, 160),
	Vector2(48, 144),
	Vector2(80, 160),
	Vector2(80, 128),
	Vector2(16, 96),
	Vector2(32, 16),
	Vector2(48, 16),
	Vector2(64, 16),
	Vector2(32, 96),
	Vector2(48, 96),
	Vector2(64, 96),
	Vector2(32, 0),
	Vector2(48, 0),
	Vector2(64, 0),
	Vector2(32, 80),
	Vector2(48, 80),
	Vector2(64, 80),
	Vector2(0, 32),
	Vector2(0, 48),
	Vector2(0, 64),
	Vector2(80, 32),
	Vector2(80, 48),
	Vector2(80, 64),
	Vector2(16, 32),
	Vector2(32, 32),
	Vector2(16, 48),
	Vector2(32, 48),
	Vector2(16, 64),
	Vector2(32, 64),
]
const SWE_OBJECT_TABLE = {
	"obj_block_res": preload("uid://k7sykscno8vb"),
	"obj_qblock_res": preload("uid://b7i6hre4grgbn"),
	"obj_coin_res": preload("uid://cxu0namx61nsi"),
	"obj_mushroom_res": preload("res://scenes/level/parts/mushroom_part.tscn"),
	"obj_fireflower_res": preload("res://scenes/level/parts/fire_flower_part.tscn"),
	"obj_star_res": preload("res://scenes/level/parts/star_part.tscn"),
	"obj_1up_res": preload("res://scenes/level/parts/one_up_part.tscn"),
	"obj_rock_res": preload("res://scenes/level/parts/hard_block_part.tscn"),
	"obj_block_hidden_res": preload("res://scenes/level/parts/hidden_block_part.tscn"),
	"obj_ice_res": preload("res://scenes/level/parts/ice_block_part.tscn"),
	"obj_pinchos_res": preload("res://scenes/level/parts/spike_part.tscn"),
	"obj_nube_res": preload("res://scenes/level/parts/cloud_part.tscn"),
	"obj_donut_res": preload("res://scenes/level/parts/donut_part.tscn"),
	"obj_noteblock_res": preload("res://scenes/level/parts/note_block_part.tscn"),
	"obj_spring_res": preload("res://scenes/level/parts/spring_part.tscn"),
	# The pinned OpenWE has unfinished slopes and no endpoint save contract.
	# Keep this explicit extension instead of misidentifying its ground objects.
	"godotwe_slope": preload("res://scenes/level/parts/slope_part.tscn"),
	"godotwe_gentle_slope": preload("res://scenes/level/parts/gentle_slope_part.tscn"),
	"obj_goomba_res": preload("res://scenes/level/parts/goomba_part.tscn"),
	"obj_goombrat_res": preload("res://scenes/level/parts/goomba_part.tscn"),
	"obj_koopa_res": preload("res://scenes/level/parts/koopa_part.tscn"),
	"obj_koopa_red_res": preload("res://scenes/level/parts/koopa_part.tscn"),
	"obj_buzzybeetle_res": preload("res://scenes/level/parts/buzzy_part.tscn"),
	"obj_buzzy_shell_res": preload("res://scenes/level/parts/buzzy_part.tscn"),
	"obj_spiny_res": preload("res://scenes/level/parts/spiny_part.tscn"),
	"obj_spiny_shell_res": preload("res://scenes/level/parts/spiny_part.tscn"),
	"obj_blooper_res": preload("res://scenes/level/parts/blooper_part.tscn"),
	"obj_cheepcheep_res": preload("res://scenes/level/parts/cheep_cheep_part.tscn"),
	"obj_cheepcheep2_res": preload("res://scenes/level/parts/cheep_cheep_part.tscn"),
	"obj_pplant_res": preload("res://scenes/level/parts/piranha_part.tscn"),
	"obj_plant_fire_res": preload("res://scenes/level/parts/piranha_part.tscn"),
	"obj_muncher_res": preload("res://scenes/level/parts/muncher_part.tscn"),
	"obj_muncher_b_res": preload("res://scenes/level/parts/muncher_part.tscn"),
	"obj_thwomp_res": preload("res://scenes/level/parts/thwomp_part.tscn"),
	"obj_thwomp_b_res": preload("res://scenes/level/parts/thwomp_part.tscn"),
	"obj_grrrol_res": preload("res://scenes/level/parts/thwomp_part.tscn"),
	"obj_grrrol_new_res": preload("res://scenes/level/parts/grrrol_part.tscn"),
	"obj_grrrol_b_res": preload("res://scenes/level/parts/grrrol_part.tscn"),
	"obj_monty_res": preload("res://scenes/level/parts/monty_part.tscn"),
	"obj_rocky_res": preload("res://scenes/level/parts/rocky_part.tscn"),
	"obj_hammerbro_res": preload("res://scenes/level/parts/hammer_bro_part.tscn"),
	"obj_firebro_res": preload("res://scenes/level/parts/hammer_bro_part.tscn"),
	"obj_icebro_res": preload("res://scenes/level/parts/hammer_bro_part.tscn"),
	"obj_boomerangbro_res": preload("res://scenes/level/parts/hammer_bro_part.tscn"),
	"obj_sledgebro_res": preload("res://scenes/level/parts/hammer_bro_part.tscn"),
	"obj_chomp_res": preload("res://scenes/level/parts/chomp_part.tscn"),
	"obj_chomp_b_res": preload("res://scenes/level/parts/chomp_part.tscn"),
	"obj_goalgate": preload("res://scenes/level/parts/goal_pole_part.tscn"),
	"obj_flagpole": preload("res://scenes/level/parts/goal_pole_part.tscn"),
}
const SWE_THEME_ALIASES := {"GROUND": "OVERWORLD", "GHOST": "MANSION"}

var _thread := Thread.new()
var _semaphore := Semaphore.new()
var _queue: Array[Dictionary] = []
var _queue_mutex := Mutex.new()
var _last_id := 0


func _ready() -> void:
	var err = _thread.start(_run)
	if err != OK:
		OS.alert("GodotWE failed to start the level processor thread: %s. The game cannot continue! Try again later." % error_string(err))
		get_tree().quit(err)


func _exit_tree() -> void:
	if _thread.is_started():
		_queue_mutex.lock()
		_queue.push_back({"command": _Command.EXIT})
		_queue_mutex.unlock()
		_semaphore.post()
		_thread.wait_to_finish()


## Decodes a SWE file's JSON content. The returned [Dictionary] contains two
## entries:
## 	• [code]verified[/code] - a [bool] for whether the hash within the file is
## correct as an "anti-tamper" measure;
## 	• [code]data[/code] - the parsed JSON data.
## Returns an empty dictionary if decoding failed.
## [b]Note:[/b] The parsed JSON can be any valid JSON value, however, if
## untampered, the parsed data should always be a [Dictionary].
func decode_swe(data: PackedByteArray) -> Dictionary:
	print("Decoding SWE file...")
	var crypto = Crypto.new()
	var json = JSON.new()
	
	if data.size() < 41:
		push_error("File is too small")
		return {}
	
	var end_size: int
	if data.decode_u8(data.size() - 1) == 0:
		print("End contains null byte")
		end_size = -1
	else:
		print("End does not contain null byte")
		end_size = 0
	
	var b64 = data.slice(0, end_size - 40)
	var stored_hash = data.slice(end_size - 40, data.size() + end_size) \
			.get_string_from_utf8()
	var expected_hash = crypto.hmac_digest(HashingContext.HASH_SHA1,
			SWE_HMAC_KEY.to_utf8_buffer(), b64).hex_encode()
	print("Stored hash: %s" % stored_hash)
	print("Expected hash: %s" % expected_hash)
	
	var raw = Marshalls.base64_to_utf8(b64.get_string_from_utf8())
	if raw == "":
		push_error("Base64 decoding failed or raw JSON is empty")
		return {}
	
	var err = json.parse(raw)
	if err != OK:
		push_error("JSON parsing failed (%s) at line %d: %s" % [
				err,
				json.get_error_line(),
				json.get_error_message()])
		return {}
	
	print("SWE decoding done!")
	return {
		"verified": expected_hash == stored_hash,
		"data": json.data,
	}


## Loads a [Level] from an SMM:WE SWE level file. Only loads basic level
## information if [param meta_only] is [code]true[/code]. The loader is very
## lenient and accepts unusual values and missing fields that are only possible
## by tampering. If a value is unusable, it uses the default values.
func from_swe(path: String, meta_only := false) -> Level:
	return await _request({
		"command": _Command.LOAD,
		"path": path,
		"meta_only": meta_only,
	})


## Saves a main-thread snapshot, then stages and replaces it on the worker.
## Returns {error: Error, message: String}; failed writes keep the original.
func save_swe(level: Level, path: String) -> Dictionary:
	if not is_instance_valid(level):
		return {"error": ERR_INVALID_PARAMETER, "message": "No level is open."}
	if path.is_empty() or path.get_extension().to_lower() != "swe":
		return {"error": ERR_INVALID_PARAMETER, "message": "Choose a .swe file."}
	var snapshot := SWELevelSerializer.snapshot(level, SWE_OBJECT_TABLE, SWE_GROUND_FRAME_TABLE)
	if snapshot.error != OK:
		return snapshot
	var result: Dictionary = await _request({
		"command": _Command.SAVE,
		"path": path,
		"data": snapshot.data,
	})
	if result.error == OK and is_instance_valid(level):
		level.file_path = path
		level.source_swe = snapshot.data
		# A successfully serialized new course is now a complete SWE source too.
		level.swe_load_complete = true
		level.swe_revision += 1
		for binding: Dictionary in snapshot.bindings:
			if is_instance_valid(binding.part):
				binding.part.swe_data = binding.entry.duplicate(true)
				binding.part.swe_source_index = binding.index
				binding.part.swe_revision = level.swe_revision
	return result


## Encodes the legacy base64 JSON + hex HMAC-SHA1 envelope.
func encode_swe(data: Dictionary) -> PackedByteArray:
	var b64 := Marshalls.utf8_to_base64(JSON.stringify(data)).to_utf8_buffer()
	var digest := Crypto.new().hmac_digest(HashingContext.HASH_SHA1,
			SWE_HMAC_KEY.to_utf8_buffer(), b64).hex_encode().to_utf8_buffer()
	b64.append_array(digest)
	return b64
	


func _request(data: Dictionary) -> Variant:
	_last_id += 1
	var request_id := _last_id
	data.id = request_id
	_queue_mutex.lock()
	_queue.push_back(data)
	_queue_mutex.unlock()
	_semaphore.post()
	var response: Array
	while true:
		response = await _done
		if response[0] == request_id:
			break
	return response[1]


func _from_swe(path: String, meta_only := false) -> Level:
	#region decoding and preparation
	print_rich("[b]Loading level at path [code]%s[/code]...[/b]" % path)
	
	var result = decode_swe(FileAccess.get_file_as_bytes(path))
	if result.is_empty():
		push_error("SWE decoding failed during level loading")
		return
	# Load after autoload scripts are initialized: the editor save API also
	# references LevelProcessor, so preloading the level scene forms a cycle.
	var lvl: Level = load("res://scenes/templates/level_template.tscn").instantiate()
	if not result.verified:
		push_error("Level file is tampered (hashes do not match)")
		lvl.free()
		return null
	if result.data is not Dictionary:
		push_error("Expected Dictionary at root, got %s" %
				type_string(typeof(result.data)))
		lvl.free()
		return null
	#endregion
	
	print("Decoding and Preparation DONE")
	
	#region sections
	var data: Dictionary = result.data
	lvl.source_swe = data.duplicate(true)
	lvl.metadata_only = meta_only
	var wrapper: Dictionary
	var list: Array
	var terrain: Array
	var objects: Array
	
	var _wrapper = _get_value(data, "S0", "MAIN")
	if _wrapper is Dictionary:
		wrapper = _wrapper
	else:
		_warn_type("Wrapper", _wrapper)
		return lvl
		
	var _list = _get_value(wrapper, "S1", "AJUSTES")
	if _list is Array:
		list = _list
	else:
		_warn_type("Settings list", _list)
		return lvl
	
	var _terrain = _get_value(wrapper, "S2", "SUELO")
	if _terrain is Array:
		terrain = _terrain
	else:
		_warn_type("Terrain", _terrain)
		return lvl
	
	var _objects = _get_value(wrapper, "S4", "NIVEL")
	if _objects is Array:
		objects = _objects
	else:
		_warn_type("Objects", _objects)
		return lvl
	#endregion
	
	print("Sections DONE")
	
	#region level metadata
	if list.is_empty() or list[0] is not Dictionary:
		_warn_type("First settings entry", list)
		lvl.free()
		return null
	var map: Dictionary = list[0]
	
	lvl.level_name = path.get_basename().get_file()
	lvl.file_path = path
	var width_value: Variant = _get_value(map, "width", "size")
	if _is_integer(width_value):
		lvl.width = clampi(int(width_value), 496, 9216)
	
	lvl.creation_date = str(_get_value(map, "date", "date"))
	lvl.creation_time = str(_get_value(map, "time", "time"))
	
	var _tag_1 = posmod(_int_value(_get_value(map, "label_1", "etiqueta1")) + 1, Level.Tag.size())
	var _tag_2 = posmod(_int_value(_get_value(map, "label_2", "etiqueta2"), -1) + 1, Level.Tag.size())
	# handling casting manually so 'as' doesn't make a runtime error
	if _tag_1 in Level.Tag.values():
		lvl.tag_1 = _tag_1 as Level.Tag
	if _tag_2 in Level.Tag.values():
		lvl.tag_2 = _tag_2 as Level.Tag
	
	var condition = _int_value(_get_value(map, "c_conditions", "condiciones_count"))
	if condition in Level.ClearCondition.values():
		lvl.clear_condition = condition as Level.ClearCondition
	
	var _author = map.get("user")
	if _author != null:
		lvl.author = str(_author)
	else:
		_warn_type("Author", _author)
	
	var style: Variant = _get_value(map, "gamestyle", "apariencia")
	if _is_integer(style) and int(style) in Level.GameStyle.values():
		lvl.game_style = int(style) as Level.GameStyle
	else:
		_warn_type("Game style", style)
	var clock: Variant = _get_value(map, "timer", "cronometro")
	if _is_integer(clock) and int(clock) >= 10 and int(clock) <= 500:
		lvl.time = int(clock)
	else:
		_warn_type("Timer", clock)
		lvl.time = 300
	
	var _description = _get_value(map, "desc", "description")
	if _description != null:
		lvl.description = str(_description)
	else:
		_warn_type("Description", _description)
	#endregion
	
	print("Level Metadata DONE")
	
	#region sub-area metadata
	var sub: SubArea = lvl.current_sub_area
	
	var _level_theme = str(_get_value(map, "gametheme", "entorno")).to_upper()
	_level_theme = SWE_THEME_ALIASES.get(_level_theme, _level_theme)
	if _level_theme in Level.LevelTheme:
		sub.level_theme = Level.LevelTheme[_level_theme]
	else:
		_warn_type("Level theme", _level_theme)

	var night: Variant = _get_value(map, "nightmode", "modo_noche")
	sub.night_mode = night if night is bool else _int_value(night) == 1
	for entry in [["water_level", "water_start_y"], ["water_level_limit", "water_limit_y"]]:
		var value: Variant = map.get(entry[0], 416)
		if (value is int or value is float) and is_finite(float(value)):
			sub.set(entry[1], float(value) - 432)
		else:
			_warn_type(entry[0], value)
	var water_speed: Variant = map.get("water_level_speed", 0.2)
	if water_speed is int or water_speed is float:
		for index in 3:
			if is_equal_approx(float(water_speed), [0.2, 0.5, 0.8][index]):
				sub.water_speed = index
	#endregion
	
	print("Sub-Area Metadata DONE")
	
	if meta_only:
		return lvl
	var starting_ground: StartingGround = sub.get_parts().get_node("StartingGround")
	var start_height: Variant = _get_value(map, "start_y", "ground2")
	if _is_integer(start_height):
		starting_ground.position.y = clampf(float(start_height) - 432, -432, 0)
	# OpenWE derives the course spawn from ground2; obj_mariostart is the
	# course-intro overlay, not a serializable player/start marker.
	sub.get_parts().get_node("EditorPlayer").position = Vector2(56, starting_ground.position.y - 16)
	
	#region sub-area terrain
	for source_index in terrain.size():
		var i: Variant = terrain[source_index]
		if i is Dictionary:
			var ground: GroundPart = preload("uid://dpfaa6qawfnk1").instantiate()
			sub.add_part(ground)
			ground.owner = lvl
			ground.level = lvl
			ground.sub_area = sub
			ground.swe_data = i.duplicate(true)
			ground.swe_source_index = source_index
			var xx = _int_value(_get_value(i, "xx", "x_pos"))
			var yy = _int_value(_get_value(i, "yy", "y_pos"), 432)
			ground.global_position = Level.snap(Vector2(xx, yy - 432))
			var idx: Variant = _get_value(i, "i", "index")
			if _is_integer(idx) and int(idx) >= 0 and int(idx) < SWE_GROUND_FRAME_TABLE.size():
				ground.swe_frame = int(idx)
				ground.swe_atlas = SWE_GROUND_FRAME_TABLE[int(idx)]
			else:
				_warn_type("Ground frame", idx)
	#endregion
	
	print("Sub-Area Terrain DONE")
	
	#region sub-area objects
	var unknown_ids: Dictionary = {}
	var has_goal := false
	for source_index in objects.size():
		var i: Variant = objects[source_index]
		if i is Dictionary:
			var id = _get_value(i, "ID", "object")
			if id == null:
				continue
			else:
				id = str(id)
			if id not in SWE_OBJECT_TABLE:
				unknown_ids[id] = int(unknown_ids.get(id, 0)) + 1
				continue
			var xx = _int_value(_get_value(i, "xx", "x_pos"))
			var yy = _int_value(_get_value(i, "yy", "y_pos"), 432)
			var scn: PackedScene = SWE_OBJECT_TABLE[id]
			var obj = scn.instantiate()
			obj.swe_data = i.duplicate(true)
			obj.swe_source_index = source_index
			obj.global_position = Level.snap(Vector2(xx, yy - 432))
			if obj is SlopePart:
				var height: Variant = i.get("slope_rise", 1)
				obj.rise = clampi(int(height), 1, SlopePart.MAX_RISE) if _is_integer(height) else 1
				obj.rises_right = i.get("slope_right", 1) != 0
			if obj is GoombaPart:
				obj.variant = GoombaPart.variant_for_object(id)
			if obj is KoopaPart:
				obj.variant = KoopaPart.variant_for_object(id)
			if obj is BuzzyPart:
				obj.variant = BuzzyPart.variant_for_object(id)
			if obj is SpinyPart:
				obj.variant = SpinyPart.variant_for_object(id)
			if obj is CheepCheepPart:
				obj.variant = CheepCheepPart.variant_for_object(id)
			if obj is PiranhaPart:
				obj.variant = PiranhaPart.variant_for_object(id)
			if obj is MuncherPart:
				obj.variant = MuncherPart.variant_for_object(id)
				obj.position.x -= obj.variant.source_x_offset
			if obj is ThwompPart:
				obj.variant = ThwompPart.variant_for_object(id)
				obj.position = Vector2(xx, yy - 432)
				var rolling: bool = obj.variant is GrrrolVariant
				if rolling:
					obj.position = Vector2(_float_value(_get_value(i, "xx", "x_pos")), _float_value(_get_value(i, "yy", "y_pos"), 432) - 432)
				var direction_value: Variant = i.get("direct_t", 2 if rolling else 1)
				obj.attack_direction = int(direction_value) if _is_integer(direction_value) and int(direction_value) in ([2, 3] if rolling else [1, 2, 3]) else 2 if rolling else 1
				obj.wings = _is_integer(i.get("wings", 0)) and int(i.get("wings", 0)) == 1
				obj.parachute = _is_integer(i.get("paracaidas", 0)) and int(i.get("paracaidas", 0)) == 1
			if obj is MontyPart:
				# obj_monty_res keeps its authored, usually off-grid cell origin;
				# scr_edit_to_play adds +8 only when the runtime actor is built.
				obj.position = Vector2(xx, yy - 432)
			if obj is RockyPart:
				# Same off-grid cell anchor; runtime build adds the +8 x offset.
				obj.position = Vector2(xx, yy - 432)
			if obj is ChompPart:
				obj.variant = ChompPart.variant_for_object(id)
				obj.position = Vector2(_float_value(_get_value(i, "xx", "x_pos")),
						_float_value(_get_value(i, "yy", "y_pos"), 432) - 432)
			if obj is HammerBroPart:
				obj.variant = HammerBroPart.variant_for_object(id)
				obj.position = Vector2(xx, yy - 432)
				obj.wings = _is_integer(i.get("wings", 0)) and int(i.get("wings", 0)) == 1
				obj.parachute = _is_integer(i.get("paracaidas", 0)) and int(i.get("paracaidas", 0)) == 1
			if obj is GoombaPart or obj is KoopaPart or obj is BuzzyPart or obj is SpinyPart or obj is CheepCheepPart or obj is PiranhaPart or obj is MuncherPart or obj is MontyPart or obj is ChompPart:
				obj.wings = _is_integer(i.get("wings", 0)) and int(i.get("wings", 0)) == 1
				obj.parachute = _is_integer(i.get("paracaidas", 0)) and int(i.get("paracaidas", 0)) == 1
			if obj is FireFlowerPart:
				obj.progressive = _is_integer(i.get("progresivo", 0)) and int(i.get("progresivo", 0)) == 1
			if obj is ContainerBlockPart and i.has("sprout"):
				var sprout: Variant = i.sprout
				if _is_integer(sprout) and int(sprout) in [0, 1, 2, -21, -18, -1]:
					var progressive := _is_integer(i.get("progresivo", 0)) and int(i.get("progresivo", 0)) == 1
					match int(sprout):
						0: obj.set_variant(obj.default_content())
						1: obj.set_variant(&"mushroom")
						2: obj.set_variant(&"progressive_flower" if progressive else &"flower")
						-21: obj.set_variant(&"star")
						-18: obj.set_variant(&"one_up")
						-1: obj.set_variant(&"none" if obj is NoteBlockPart else &"coin" if obj is HiddenBlockPart else &"multi_coin")
				else:
					push_warning("Unsupported SWE block content '%s' in %s" % [sprout, path])
			if obj is GoalPolePart:
				# Goal coordinates are not on the 16px terrain grid (137px tall).
				obj.position = Vector2(xx, yy - 432)
				has_goal = true
			sub.add_part(obj)
			obj.owner = lvl
			obj.level = lvl
			obj.sub_area = sub
	# Resizable resources have their own source collection; do not put these
	# records into NIVEL or consume unsupported platform rows on saving.
	var platforms: Variant = _get_value(wrapper, "S7", "PLATAFORMAS")
	if platforms is Array:
		for source_index in platforms.size():
			var entry: Variant = platforms[source_index]
			if entry is not Dictionary or str(_get_value(entry, "ID", "object")) != "obj_semisolid_platform1":
				continue
			var platform := SemisolidPart.create()
			platform.swe_data = entry.duplicate(true)
			platform.swe_source_index = source_index
			var w: Variant = entry.get("width", 3)
			var h: Variant = entry.get("height", 3)
			var color: Variant = entry.get("color", 0)
			platform.dimensions = Vector2i(clampi(int(w), 3, 21) if _is_integer(w) else 3,
					clampi(int(h), 3, 27) if _is_integer(h) else 3)
			platform.appearance = clampi(int(color), 0, 2) if _is_integer(color) else 0
			platform.position = Level.snap(Vector2(_float_value(_get_value(entry, "xx", "x_pos")),
					_float_value(_get_value(entry, "yy", "y_pos"), 432) - 432))
			sub.add_part(platform)
			platform.owner = lvl
	# Door pairs have their own source collection, like platforms. One row
	# holds both doors, each by the middle of its 16x32 body.
	var doors: Variant = wrapper.get("PUERTAS", [])
	if doors is Array:
		for source_index in doors.size():
			var entry: Variant = doors[source_index]
			if entry is not Dictionary or str(_get_value(entry, "ID", "object")) != "obj_door_res":
				continue
			var door := DoorPart.create()
			door.swe_data = entry.duplicate(true)
			door.swe_source_index = source_index
			door.position = Level.snap(Vector2(_float_value(entry.get("x_pos")),
					_float_value(entry.get("y_pos"), 432) - 448))
			var exit := DoorPart.create()
			exit.primary = false
			exit.position = Level.snap(Vector2(_float_value(entry.get("door_x"), door.position.x + 16),
					_float_value(entry.get("door_y"), door.position.y + 448) - 448))
			door.partner = exit
			exit.partner = door
			for part in [door, exit]:
				sub.add_part(part)
				part.owner = lvl
	for id: String in unknown_ids:
		push_warning("Unsupported SWE object '%s' (%d instance(s)) in %s" %
				[id, unknown_ids[id], path])
	# OpenWE normally derives its goal from the end-ground settings instead
	# of storing the gate in NIVEL. Accept explicit gates in generated levels.
	if not has_goal and map.has("ground3_x") and map.has("ground3_y"):
		var goal := preload("res://scenes/level/parts/goal_pole_part.tscn").instantiate()
		goal.position = Vector2(float(map.ground3_x), float(map.ground3_y) - 432 - 137)
		sub.add_part(goal)
		goal.owner = lvl
	#endregion
	
	print("Sub-Area Objects DONE")
	
	lvl.swe_load_complete = true
	return lvl


func _run() -> void:
	while true:
		_semaphore.wait()
		_queue_mutex.lock()
		var request = _queue.pop_front()
		_queue_mutex.unlock()
		match request.command:
			_Command.EXIT:
				return
			_Command.LOAD:
				var level = _from_swe(request.path, request.meta_only)
				_done.emit.bind(request.id, level).call_deferred()
			_Command.SAVE:
				var saved := _save_swe(request.path, request.data, request.id)
				_done.emit.bind(request.id, saved).call_deferred()
			_Command.BUILD:
				# TODO: move part building off to thread when switching level to
				# playing
				pass
		


static func _warn_type(key: String, value: Variant) -> void:
	push_warning("%s is invalid value %s (type %s)" %
			[key, value, type_string(typeof(value))])
 

static func _get_value(dict: Dictionary, new: String, old: String) -> Variant:
	return dict.get(new if new in dict else old)


static func _is_integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


static func _int_value(value: Variant, fallback := 0) -> int:
	if value is int or (value is float and is_finite(value)):
		return int(value)
	if value is bool:
		return 1 if value else 0
	if value is String and value.is_valid_int():
		return value.to_int()
	return fallback


static func _float_value(value: Variant, fallback := 0.0) -> float:
	return float(value) if (value is int or value is float) and is_finite(float(value)) else fallback


func _save_swe(path: String, data: Dictionary, request_id: int) -> Dictionary:
	var temporary := "%s.tmp-%d-%d" % [path, OS.get_process_id(), request_id]
	var backup := temporary + ".backup"
	if FileAccess.file_exists(temporary) or FileAccess.file_exists(backup):
		return {"error": ERR_ALREADY_EXISTS, "message": "A previous temporary save exists; choose another filename."}
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"error": FileAccess.get_open_error(), "message": "Cannot write to the selected folder."}
	file.store_buffer(encode_swe(data))
	file.flush()
	var error := file.get_error()
	file.close()
	var had_original := FileAccess.file_exists(path)
	if error == OK and had_original:
		error = DirAccess.copy_absolute(path, backup)
	if error == OK:
		error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		DirAccess.remove_absolute(temporary)
		if had_original and not FileAccess.file_exists(path) and FileAccess.file_exists(backup):
			var restored := DirAccess.rename_absolute(backup, path)
			if restored != OK:
				return {"error": error, "message": "Save failed. Recover the original from: %s" % backup}
		if FileAccess.file_exists(backup):
			DirAccess.remove_absolute(backup)
		return {"error": error, "message": "Could not replace the level file: %s." % error_string(error)}
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	return {"error": OK, "message": "Level saved."}
