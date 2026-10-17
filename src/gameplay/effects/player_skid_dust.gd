extends Node2D
## SMW skidsmoke: five frames at 0.3 frame/tick, emitted every eight ticks.
## Owns world-anchored sprites; all timing follows the player's gameplay clock.
const INTERVAL: int = 8
const LIFETIME: int = 17
var _ticks_left: int = 0
var _puffs: Array[Dictionary] = []
var _player: Player


func _ready() -> void:
	_player = get_parent() as Player
	add_child(GameplayFreezeGate.new())


func _physics_process(_delta: float) -> void:
	for index: int in range(_puffs.size() - 1, -1, -1):
		var puff: Dictionary = _puffs[index]
		puff["age"] = int(puff["age"]) + 1
		var sprite: AnimatedSprite2D = puff["sprite"] as AnimatedSprite2D
		if int(puff["age"]) >= LIFETIME:
			sprite.queue_free()
			_puffs.remove_at(index)
		else:
			sprite.frame = mini(4, floori(float(puff["age"]) * 0.3))
	var braking: bool = _player.movement_state == PlayerMovementStateMachine.State.SKID and _player.power_phase == PowerUpManager.Phase.ACTIVE and not GameManager.is_gameplay_frozen
	if not braking:
		_ticks_left = 0
		return
	if _ticks_left <= 0:
		_emit_puff()
		_ticks_left = INTERVAL
	_ticks_left -= 1


func _emit_puff() -> void:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	add_child(sprite)
	BasicSpriteLibrary.apply(sprite, "skid_dust")
	sprite.top_level = true
	sprite.scale = Vector2.ONE * 0.5
	sprite.global_position = Vector2(_player.global_position.x - _player.motion.facing * 2.0, _player.feet_y() - 2.0)
	_puffs.append({"sprite": sprite, "age": 0})


func clear() -> void:
	for puff: Dictionary in _puffs:
		var sprite: AnimatedSprite2D = puff["sprite"] as AnimatedSprite2D
		sprite.visible = false
		sprite.queue_free()
	_puffs.clear()
	_ticks_left = 0
