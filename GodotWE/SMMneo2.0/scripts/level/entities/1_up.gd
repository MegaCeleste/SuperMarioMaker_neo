class_name OneUp
extends CharacterBodyExt


func _physics_process(_delta: float) -> void:
	move_and_slide()


func _body_entered(body: Node2D) -> void:
	body = body as Player
	if body == null:
		return
	#body.set_powerup(SuperPowerup.new(), true)
	#加1up
	queue_free()
