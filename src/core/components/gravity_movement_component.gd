class_name GravityMovementComponent
extends Node
## 敌人巡逻走动、撞墙调头、悬崖检测（REQ-REG-005）
## 挂载对象为 CharacterBody2D；重力参数由宿主场景提供。

@export var walk_speed := 30.0
## 初始朝左移动
@export var start_left := true
@export var gravity := 900.0
## 悬崖边是否调头（false = 直接走落）
@export var turn_at_cliff := false

var direction := 1.0

var _body: CharacterBody2D
var _cliff_check: RayCast2D

func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	direction = -1.0 if start_left else 1.0
	if turn_at_cliff:
		_cliff_check = RayCast2D.new()
		_cliff_check.position = Vector2(8, 0)
		_cliff_check.target_position = Vector2(0, 24)
		_cliff_check.collision_mask = 1
		_body.add_child.call_deferred(_cliff_check)

func apply_movement(delta: float) -> void:
	if _body == null:
		return
	if not _body.is_on_floor():
		_body.velocity.y = minf(_body.velocity.y + gravity * delta, 400.0)
	if _body.is_on_wall():
		direction = -direction
	if turn_at_cliff and _body.is_on_floor() and _cliff_check != null \
			and not _cliff_check.is_colliding():
		direction = -direction
		_cliff_check.position.x = 8.0 * direction
	_body.velocity.x = walk_speed * direction
	_body.move_and_slide()
