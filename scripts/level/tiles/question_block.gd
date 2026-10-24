class_name QuestionBlock
extends StaticBodyExt


func _ready() -> void:
	SpriteLibrary.configure_sprite(%Sprite, &"spr_qblock", &"idle", 9, Vector2(-8, -8))


func _sprout_end(
		_eject_direction: Vector2,
		_activator: PhysicsBody2D,
		empty: bool) -> void:
	if empty:
		show_used_art()
		%BlockComponent.enabled = false


func show_used_art() -> void:
	%Sprite.sprite_frames = SpriteLibrary.get_animations({"used": ["spr_qblock_empty", 0, false, [0]]})
	%Sprite.play(&"used")
