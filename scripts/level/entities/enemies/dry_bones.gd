# SPDX-License-Identifier: AGPL-3.0-or-later
class_name DryBones
extends Enemy
## SMW Dry Bones (source obj_drybones, obj_crumblebones). It walks at
## 0.5px/tick and turns at ledges. A stomp collapses it (snd_crumble): the
## standing frame for 8 ticks, a heap for 200, then 10 shakes of 5 ticks each
## way and 8 more ticks before it stands up and walks on. Collapsed bones
## cannot be hurt; fireballs bounce off it; star power and a POW defeat it.

const COLLAPSE_TICKS := 8
const HEAP_TICKS := 200
const SHAKES := 10
const SHAKE_TICKS := 5
const STAND_TICKS := 8

## Ticks since the collapse; negative while walking.
var collapsed := -1


func _ready() -> void:
	super()
	hardness = 6
	fireproof = true
	SpriteLibrary.configure_sprite(%Sprite, &"spr_drybones", &"walk", 9, Vector2(0, -16))
	# Source direct starts at -1: face the walking direction before any turn.
	_turned(Vector2.RIGHT if $SlideComponent.direction > 0 else Vector2.LEFT)


func _physics_process(delta: float) -> void:
	if collapsed < 0:
		super(delta)
		return
	if source_death_stopped():
		return
	velocity.x = 0
	$GravityComponent._physics_process(delta)
	move_source_and_slide()
	collapsed += 1
	var sprite: AnimatedSprite2D = %Sprite
	var heap_end := COLLAPSE_TICKS + HEAP_TICKS
	var shake_end := heap_end + SHAKES * SHAKE_TICKS * 2
	if collapsed == COLLAPSE_TICKS:
		sprite.frame = 1
	elif collapsed > heap_end and collapsed <= shake_end:
		# Source Alarm_1/2: one pixel right for 5 ticks, back for 5.
		sprite.position.x = 1 if floori((collapsed - heap_end - 1) / float(SHAKE_TICKS)) % 2 == 0 else 0
	elif collapsed == shake_end + 1:
		sprite.position.x = 0
		sprite.frame = 0
	elif collapsed >= shake_end + STAND_TICKS:
		stand_up()


func _stomped(player: Player) -> void:
	if is_queued_for_deletion() or player.is_dead() or collapsed >= 0:
		return
	player.bounce()
	player.sounds.stream = preload("uid://c345xnns7om3m")
	player.sounds.play()
	collapse()


func collapse() -> void:
	collapsed = 0
	hardness = 100
	$SlideComponent.process_mode = Node.PROCESS_MODE_DISABLED
	velocity.x = 0
	EnemyEffect.sound_once(sub_area, SoundLibrary.path("snd_crumble"))
	SpriteLibrary.configure_sprite(%Sprite, &"spr_drybones_crumble", &"crumble", 0, Vector2(0, -16))
	%Sprite.stop()
	%Sprite.frame = 0


func stand_up() -> void:
	collapsed = -1
	hardness = 6
	$SlideComponent.process_mode = Node.PROCESS_MODE_INHERIT
	SpriteLibrary.configure_sprite(%Sprite, &"spr_drybones", &"walk", 9, Vector2(0, -16))


func hit_by_projectile(kind: StringName, launch_direction := 0.0) -> bool:
	if collapsed >= 0 or kind == &"fire":
		return false
	return super(kind, launch_direction)


func _turned(direction: Vector2) -> void:
	%Sprite.flip_h = direction == Vector2.LEFT


func get_defeat_sprite() -> StringName:
	return &"spr_drybones_deads"
