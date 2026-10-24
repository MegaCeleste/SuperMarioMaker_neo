extends Node
## Verifies the OpenWE sprite conversion pipeline at runtime.

const EXPECTED := {
	"spr_1up": {"frames": 2, "size": Vector2i(16, 16)},
	"spr_coin": {"frames": 8, "size": Vector2i(16, 16)},
	"spr_goomba_res": {"frames": 4, "size": Vector2i(16, 18)},
	"spr_ground": {"frames": 74, "size": Vector2i(16, 16)},
	"spr_grrrol_b": {"frames": 4, "size": Vector2i(65, 65), "origin": Vector2(32, 32)},
}


func _ready() -> void:
	var ok := true
	for name: String in EXPECTED:
		if not SpriteLibrary.has_sprite(name):
			push_error("sprite missing from manifest: %s" % name)
			ok = false
			continue
		var frames := SpriteLibrary.get_frames(name)
		var expected: Dictionary = EXPECTED[name]
		var actual_frames := frames.get_frame_count(&"default")
		if actual_frames != expected["frames"]:
			push_error("%s: expected %d frames, got %d" % [
					name, expected["frames"], actual_frames])
			ok = false
		var texture := frames.get_frame_texture(&"default", 0)
		if texture == null:
			push_error("%s: first frame texture is null" % name)
			ok = false
			continue
		if texture.get_size() != Vector2(expected["size"]):
			push_error("%s: expected size %s, got %s" % [
					name, expected["size"], texture.get_size()])
			ok = false
		var sprite := SpriteLibrary.make_sprite(name)
		if expected.has("origin") and SpriteLibrary.get_origin(name) != expected.origin:
			push_error("%s: serialized source origin changed" % name)
			ok = false
		if sprite.offset != -SpriteLibrary.get_origin(name):
			push_error("%s: origin offset mismatch" % name)
			ok = false
		sprite.free()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://resources/content/smw_player_sprites.json"))
	for power: String in catalog:
		var mapping: Dictionary = catalog[power]
		var animations := SpriteLibrary.get_animations(mapping)
		if animations == null:
			push_error("Missing converted player animations for %s" % power)
			ok = false
			continue
		for animation: String in mapping:
			var entry: Array = mapping[animation]
			if animations.get_frame_count(animation) == 0 \
					or animations.get_animation_speed(animation) != float(entry[1]) \
					or animations.get_animation_loop(animation) != bool(entry[2]):
				push_error("Invalid manifest animation %s/%s" % [power, animation])
				ok = false
	print("SPRITE_LIBRARY_RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
