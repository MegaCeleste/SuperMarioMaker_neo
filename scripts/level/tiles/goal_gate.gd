# SPDX-License-Identifier: AGPL-3.0-or-later
class_name GoalGate
extends Area2D
## SMW goal trigger, adapted from obj_goalgate/Step_0.gml. The moving tape
## moves between the posts; entering the gate starts the SMW clear sequence.

var level: Level
var _tape: AnimatedSprite2D
var _tape_direction := 1.0


func _ready() -> void:
	if SpriteLibrary.has_sprite(&"spr_goalgate"):
		for x in [0, 32]:
			var post := SpriteLibrary.make_sprite(&"spr_goalgate")
			post.position.x = x
			add_child(post)
	if SpriteLibrary.has_sprite(&"spr_goal"):
		_tape = SpriteLibrary.make_sprite(&"spr_goal")
		_tape.position = Vector2(8, 8)
		add_child(_tape)
	body_entered.connect(_body_entered)


func _physics_process(delta: float) -> void:
	if level.is_player_dying():
		return
	if _tape != null:
		_tape.position.y += _tape_direction * 60.0 * delta
		if _tape.position.y >= 121 or _tape.position.y <= 8:
			_tape.position.y = clampf(_tape.position.y, 8, 121)
			_tape_direction *= -1


func _body_entered(body: Node2D) -> void:
	if body is Player and level.status == Level.Status.PLAYING and not body.is_dead():
		level.complete(body, global_position.x + 106)
		if _tape != null:
			_tape.queue_free()
			_tape = null
