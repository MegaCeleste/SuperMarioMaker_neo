class_name Coin
extends Area2D

var _collected := false


func _ready() -> void:
	SpriteLibrary.configure_sprite($Sprite, &"spr_coin", &"default", 9)


func _body_entered(body: Node2D) -> void:
	if body is Player and not _collected and not body.is_dead():
		_collected = true
		body.collect_coin()
		var sparkle = preload("uid://b4pkpe44vveuw").instantiate()
		sparkle.global_position = global_position
		add_sibling(sparkle)
		queue_free()
