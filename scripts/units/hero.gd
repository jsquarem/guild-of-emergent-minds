class_name Hero
extends CharacterBody2D
## A single guild hero. Moves via behavior tree, tracks HP and hazard overlaps.

signal damaged(amount: float, source_type: String)
signal died(cause: String)

@export var max_hp: float = 100.0
@export var move_speed: float = 80.0

var hp: float
var is_alive: bool = true
var active_hazards: Array[Area2D] = []
var goal_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	hp = max_hp
	add_to_group("heroes")


func take_damage(amount: float, source_type: String = "unknown") -> void:
	if not is_alive:
		return
	hp -= amount
	damaged.emit(amount, source_type)
	EventBus.hero_damaged.emit(self, amount, source_type)
	if hp <= 0.0:
		hp = 0.0
		die(source_type)


func die(cause: String = "unknown") -> void:
	if not is_alive:
		return
	is_alive = false
	died.emit(cause)
	EventBus.hero_died.emit(self, cause)


func heal(amount: float) -> void:
	hp = minf(hp + amount, max_hp)


func is_in_hazard(hazard_type: String = "") -> bool:
	if hazard_type.is_empty():
		return not active_hazards.is_empty()
	for hazard in active_hazards:
		if hazard.has_method("get_hazard_type") and hazard.get_hazard_type() == hazard_type:
			return true
	return false


func register_hazard(hazard: Area2D) -> void:
	if hazard not in active_hazards:
		active_hazards.append(hazard)


func unregister_hazard(hazard: Area2D) -> void:
	active_hazards.erase(hazard)


func _draw() -> void:
	if is_alive:
		# Blue circle body
		draw_circle(Vector2.ZERO, 8.0, Color(0.2, 0.4, 0.9))
		# Direction indicator
		var dir := velocity.normalized() if velocity.length() > 0 else Vector2.RIGHT
		draw_line(Vector2.ZERO, dir * 12.0, Color.WHITE, 2.0)
		# HP bar above head
		var bar_width: float = 20.0
		var bar_y: float = -14.0
		var hp_ratio := hp / max_hp
		draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width, 3.0), Color(0.2, 0.2, 0.2))
		draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width * hp_ratio, 3.0), Color(0.1, 0.9, 0.2))
	else:
		draw_circle(Vector2.ZERO, 8.0, Color(0.3, 0.3, 0.3, 0.5))


func _process(_delta: float) -> void:
	queue_redraw()
