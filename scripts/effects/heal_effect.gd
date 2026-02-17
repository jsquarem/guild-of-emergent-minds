class_name HealEffect
extends Node2D
## Brief expanding green glow ring shown when a hero is healed.

var _lifetime: float = 0.5
var _elapsed: float = 0.0
var _max_radius: float = 16.0


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _elapsed / _lifetime
	var radius := _max_radius * (0.5 + 0.5 * t)
	var alpha := 0.6 * (1.0 - t)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(0.2, 1.0, 0.4, alpha), 2.0)
	draw_circle(Vector2.ZERO, radius * 0.5, Color(0.3, 1.0, 0.5, alpha * 0.3))
