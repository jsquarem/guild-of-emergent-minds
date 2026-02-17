class_name Projectile
extends Node2D
## Simple projectile that travels toward a target, applies damage or heal on arrival.

var target: Node2D = null
var speed: float = 300.0
var damage: float = 0.0
var heal_amount: float = 0.0
var source_type: String = "hero"
var color: Color = Color(1.0, 0.3, 0.2)
var _is_heal: bool = false


func setup(origin: Vector2, p_target: Node2D, p_damage: float, p_source_type: String, p_color: Color) -> void:
	position = origin
	target = p_target
	damage = p_damage
	source_type = p_source_type
	color = p_color
	_is_heal = false


func setup_heal(origin: Vector2, p_target: Node2D, p_heal: float, p_color: Color) -> void:
	position = origin
	target = p_target
	heal_amount = p_heal
	color = p_color
	_is_heal = true


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return

	var to_target := target.global_position - global_position
	var dist := to_target.length()

	if dist < 6.0:
		_apply_effect()
		queue_free()
		return

	global_position += to_target.normalized() * speed * delta


func _apply_effect() -> void:
	if _is_heal:
		if target is Hero and target.is_alive:
			(target as Hero).heal(heal_amount)
	else:
		if target.has_method("take_damage"):
			target.take_damage(damage, source_type)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, color)
	if _is_heal:
		draw_circle(Vector2.ZERO, 5.0, Color(color, 0.3))


func _process(_delta: float) -> void:
	queue_redraw()
