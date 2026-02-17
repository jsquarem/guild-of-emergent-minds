class_name FloatingNumber
extends Node2D
## Floating text that drifts upward and fades out. Used for damage and heal numbers.

var text: String = ""
var color: Color = Color.WHITE
var _lifetime: float = 0.8
var _elapsed: float = 0.0
var _rise_distance: float = 40.0
var _start_y: float = 0.0
var _font: Font


func _ready() -> void:
	_start_y = position.y
	_font = ThemeDB.fallback_font


static func create_damage(amount: float, pos: Vector2) -> FloatingNumber:
	var fn := FloatingNumber.new()
	fn.text = "-%d" % ceili(amount)
	fn.color = Color(1.0, 0.25, 0.2)
	fn.position = pos + Vector2(randf_range(-6, 6), -12)
	return fn


static func create_heal(amount: float, pos: Vector2) -> FloatingNumber:
	var fn := FloatingNumber.new()
	fn.text = "+%d" % ceili(amount)
	fn.color = Color(0.2, 1.0, 0.35)
	fn.position = pos + Vector2(randf_range(-6, 6), -12)
	return fn


func _process(delta: float) -> void:
	_elapsed += delta
	var t := _elapsed / _lifetime
	if t >= 1.0:
		queue_free()
		return
	position.y = _start_y - _rise_distance * t
	modulate.a = 1.0 - t * t
	queue_redraw()


func _draw() -> void:
	if _font:
		var font_size: int = 12
		var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(_font, Vector2(-text_size.x / 2.0, 0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
