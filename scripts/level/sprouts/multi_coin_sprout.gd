# SPDX-License-Identifier: AGPL-3.0-or-later
class_name MultiCoinSprout
extends CoinSprout
## Source cointime: the first bump starts a200-active-tick coin window.

var remaining := 200
var _clock: Node


func start_sprout(position: Vector2, direction: Vector2) -> void:
	super(position, direction)
	if not is_instance_valid(_clock):
		_clock = CoinClock.new()
		_clock.sprout = self
		body.add_child(_clock)
	empty = remaining <= 0


class CoinClock extends Node:
	var sprout: MultiCoinSprout

	func _physics_process(_delta: float) -> void:
		sprout.remaining = maxi(0, sprout.remaining - 1)
