class_name TurnBlockTile
extends StaticBodyExt

const TURNS = 8

var turning := false:
	set(value):
		turning = value
		if value:
			turns_done = 0
			$Sprite.play("turning")
			$CollShape.disabled = true
		else:
			$Sprite.play("idle")
			$CollShape.disabled = false
var turns_done := 0


func _ready() -> void:
	var frames := SpriteLibrary.get_animations({
		"idle": ["spr_flipblock", 1, false, [0]],
		"turning": ["spr_flipblock", 9, true],
	})
	if frames != null:
		$Sprite.sprite_frames = frames
		$Sprite.play("idle")


## A turn block with no contents, not spinning and not used up; only these
## trade places with coins under a P-switch.
func is_plain() -> bool:
	var block := $BlockComponent
	return block.sprout == null and block.enabled and not turning


func _sprout_end(_eject_direction: Vector2, _activator: PhysicsBody2D, _empty: bool) -> void:
	if $BlockComponent.sprout != null:
		if not _empty:
			return
		$Sprite.sprite_frames = SpriteLibrary.get_animations({"used": ["spr_qblock_empty", 0, false, [0]]})
		$Sprite.play(&"used")
		$BlockComponent.enabled = false
		return
	turning = true

func _sprite_animation_looped() -> void:
	turns_done += 1
	if turns_done >= TURNS and not $PlayerCheckArea.overlaps_body(
			Utility.id("player")):
		turning = false
