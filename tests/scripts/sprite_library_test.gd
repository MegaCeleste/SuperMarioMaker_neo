extends Node
## Verifies the OpenWE sprite conversion pipeline at runtime.

const EXPECTED := {
	"spr_1up": {"frames": 2, "size": Vector2i(16, 16)},
	"spr_coin": {"frames": 8, "size": Vector2i(16, 16)},
	"spr_goomba_res": {"frames": 4, "size": Vector2i(16, 18)},
	"spr_ground": {"frames": 74, "size": Vector2i(16, 16)},
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
		if sprite.offset != -SpriteLibrary.get_origin(name):
			push_error("%s: origin offset mismatch" % name)
			ok = false
		sprite.free()
	print("SPRITE_LIBRARY_RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
