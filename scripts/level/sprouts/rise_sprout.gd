class_name RiseSprout
extends Sprout

@export var item: PackedScene
@export var texture: Texture2D
@export var offset: Vector2


func end_sprout(position: Vector2, direction: Vector2) -> void:
	var sprouter = Sprouter.new()
	sprouter.item = item.instantiate()
	sprouter.texture = texture
	sprouter.global_position = position + (Vector2(-8, -8) * direction)
	sprouter.pos = position
	sprouter.dir = direction
	sprouter.off = offset
	sprouter.sub_area = _find_sub_area()
	body.add_sibling(sprouter)
	empty = true


func _find_sub_area() -> SubArea:
	var ancestor := body.get_parent()
	while ancestor != null:
		if ancestor is SubArea:
			return ancestor
		ancestor = ancestor.get_parent()
	return null


class Sprouter extends Sprite2D:
	var pos: Vector2
	var dir: Vector2
	var off: Vector2
	var item: Node
	var audio := AudioStreamPlayer.new()
	var sub_area: SubArea
	
	
	func _ready() -> void:
		z_index = GameConstants.Layers.Z_SPROUT
		add_child(audio)
		audio.stream = preload("uid://bexd6cvyd4onk")
		audio.play()
		var tween = create_tween()
		tween.tween_property(self, "global_position", pos + (Vector2(8, 8) * dir), 0.5)
		tween.tween_callback(_spawn)
	
	
	func _spawn() -> void:
		var at := global_position + off
		if item is Entity and is_instance_valid(sub_area):
			item.position = sub_area.get_foreground().to_local(at)
			sub_area.add(item)
		else:
			item.global_position = at
			add_sibling(item)
		if audio.playing:
			hide()
			await audio.finished
		queue_free()


	func _exit_tree() -> void:
		if is_instance_valid(item) and item.get_parent() == null:
			item.free()
