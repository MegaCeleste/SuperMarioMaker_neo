class_name BasicSpriteLibrary
extends RefCounted
## Reviewed frame mappings; source semantics and pipeline are in docs/architecture.md.

const PATH: String = "res://data/assets/basic_smw.json"
static var _document: Dictionary = {}
static var _cache: Dictionary[String, SpriteFrames] = {}


static func apply(sprite: AnimatedSprite2D, group: String) -> void:
	var frames: SpriteFrames = get_frames(group)
	if frames == null:
		return
	sprite.sprite_frames = frames
	var record: Dictionary = (_document["groups"] as Dictionary)[group] as Dictionary
	var offset: Array = record["offset"] as Array
	sprite.offset = Vector2(float(offset[0]), float(offset[1]))
	sprite.stop()


static func get_frames(group: String) -> SpriteFrames:
	if _cache.has(group):
		return _cache[group]
	if _document.is_empty():
		var file: FileAccess = FileAccess.open(PATH, FileAccess.READ)
		if file == null:
			push_error("Missing basic sprite catalog: " + PATH)
			return null
		var value: Variant = JSON.parse_string(file.get_as_text())
		if not value is Dictionary:
			push_error("Invalid basic sprite catalog")
			return null
		_document = value as Dictionary
	var groups: Dictionary = _document["groups"] as Dictionary
	if not groups.has(group):
		push_error("Unknown basic sprite group: " + group)
		return null
	var result: SpriteFrames = SpriteFrames.new()
	result.remove_animation(&"default")
	var definition: Dictionary = groups[group] as Dictionary
	var animations: Dictionary = definition["animations"] as Dictionary
	for name: String in animations:
		var mapping: Dictionary = animations[name] as Dictionary
		var manifest: Dictionary = (_document["assets"] as Dictionary)[mapping["asset"]] as Dictionary
		var style: String = String(manifest.get("visual_style", String(manifest["asset_id"]).get_slice("/", 0).to_lower()))
		if definition.has("visual_style") and style != String(definition["visual_style"]):
			push_error("Mixed sprite styles in animation group: " + group)
			return null
		if name == "walk" and String(manifest.get("source_role", "locomotion")) != "locomotion":
			push_error("Non-locomotion sprite mapped to walk: " + group)
			return null
		if manifest["metadata_state"] != "verified":
			push_error("Unverified basic sprite: " + String(manifest["asset_id"]))
			return null
		var texture: Texture2D = load(String(manifest["texture_path"])) as Texture2D
		var width: int = int(manifest["frame_width"])
		var height: int = int(manifest["frame_height"])
		var count: int = int(manifest["frame_count"])
		if texture == null or texture.get_width() != width * count or texture.get_height() != height:
			push_error("Basic sprite missing or size mismatch: " + String(manifest["texture_path"]))
			return null
		result.add_animation(StringName(name))
		result.set_animation_speed(StringName(name), float(mapping["fps"]))
		result.set_animation_loop(StringName(name), bool(mapping["loop"]))
		for index: int in mapping["frames"]:
			if index < 0 or index >= count:
				push_error("Basic sprite frame out of range: " + name)
				return null
			var frame: AtlasTexture = AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2(float(index * width), 0.0, float(width), float(height))
			result.add_frame(StringName(name), frame)
	_cache[group] = result
	return result
