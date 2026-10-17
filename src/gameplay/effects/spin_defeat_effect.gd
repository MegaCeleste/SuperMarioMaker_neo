extends Node2D
## SMMWE obj_spinsmoke star spread; owner requests stars only, without smoke.
## Source geometry is halved from 32px tiles to this project's 16px tiles.
const LIFETIME: int = 16
var age: int = 0
var stars: Array[AnimatedSprite2D] = []


func _ready() -> void:
	add_to_group("spin_defeat_effects")
	for index: int in 4:
		var star: AnimatedSprite2D = AnimatedSprite2D.new()
		add_child(star)
		BasicSpriteLibrary.apply(star, "spin_star")
		star.scale = Vector2.ONE * 0.5
		stars.append(star)
	add_child(GameplayFreezeGate.new())
	_render()


func _physics_process(_delta: float) -> void:
	age += 1
	if age >= LIFETIME:
		queue_free()
		return
	_render()


func _render() -> void:
	for index: int in stars.size():
		stars[index].position = Vector2(float(age) * (-1.0 if index & 1 else 1.0), float(age) * (-0.5 if index & 2 else 0.5))
