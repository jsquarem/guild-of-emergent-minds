class_name FireHazard
extends Area2D
## Area that deals damage over time to heroes standing in it.

@export var damage_per_second: float = 50.0
@export var hazard_size: Vector2 = Vector2(200, 120)

var bodies_in_hazard: Array[CharacterBody2D] = []
var _time: float = 0.0


func _ready() -> void:
	add_to_group("fire_hazards")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	_time += delta
	for body in bodies_in_hazard:
		if body is Hero and body.is_alive:
			body.take_damage(damage_per_second * delta, "fire")


func _on_body_entered(body: Node2D) -> void:
	if body is Hero:
		bodies_in_hazard.append(body)
		body.register_hazard(self)
		EventBus.hazard_entered.emit(body, "fire")


func _on_body_exited(body: Node2D) -> void:
	if body is Hero:
		bodies_in_hazard.erase(body)
		body.unregister_hazard(self)
		EventBus.hazard_exited.emit(body, "fire")


func get_hazard_type() -> String:
	return "fire"


func _draw() -> void:
	var rect := Rect2(-hazard_size / 2.0, hazard_size)
	# Pulsing fire glow
	var pulse := 0.25 + 0.1 * sin(_time * 4.0)
	draw_rect(rect, Color(0.9, 0.15, 0.05, pulse))
	draw_rect(rect, Color(1.0, 0.3, 0.0, 0.7), false, 2.0)
	# Inner flame shapes
	var inner := Rect2(-hazard_size / 4.0, hazard_size / 2.0)
	draw_rect(inner, Color(1.0, 0.6, 0.0, pulse * 0.6))


func _process(_delta: float) -> void:
	queue_redraw()
