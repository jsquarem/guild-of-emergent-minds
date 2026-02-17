class_name FireZoneEffect
extends Node2D
## Visual-only circular fire burst. Flashes on spawn, fades out, then frees itself.

var radius: float = 50.0
var _lifetime: float = 1.0
var _elapsed: float = 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _elapsed / _lifetime
	# Bright flash at start, fade to nothing
	var alpha: float
	if t < 0.15:
		alpha = 0.8
	else:
		alpha = 0.6 * (1.0 - (t - 0.15) / 0.85)
	# Outer ring
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1.0, 0.4, 0.0, alpha), 3.0)
	# Fill
	draw_circle(Vector2.ZERO, radius * (1.0 - t * 0.3), Color(0.9, 0.2, 0.05, alpha * 0.4))
	# Inner hot core
	var inner_r := radius * 0.4 * (1.0 - t)
	if inner_r > 1.0:
		draw_circle(Vector2.ZERO, inner_r, Color(1.0, 0.7, 0.1, alpha * 0.6))
