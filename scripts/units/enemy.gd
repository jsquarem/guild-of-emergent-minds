class_name Enemy
extends CharacterBody2D
## Simple enemy: patrol or aggro on sight, basic attack only. Phase 3 encounter unit.

signal died(cause: String)

@export var max_hp: float = 30.0
@export var move_speed: float = 50.0
@export var attack_damage: float = 10.0
@export var attack_range: float = 35.0
@export var attack_cooldown: float = 1.2
@export var aggro_range: float = 120.0
@export var patrol_radius: float = 0.0  ## 0 = no patrol, stand or aggro only

var hp: float
var is_alive: bool = true
var _attack_timer: float = 0.0
var _patrol_center: Vector2
var _aggro_target: Node2D = null  ## Hero or null


func _ready() -> void:
	hp = max_hp
	_patrol_center = global_position
	add_to_group("enemies")


func _physics_process(delta: float) -> void:
	if not is_alive:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_attack_timer -= delta
	_update_aggro()
	if _aggro_target:
		_behavior_combat(delta)
	else:
		_behavior_patrol(delta)
	move_and_slide()


func take_damage(amount: float, source_type: String = "unknown") -> void:
	if not is_alive:
		return
	hp -= amount
	_spawn_floating_number(amount)
	if hp <= 0.0:
		hp = 0.0
		die(source_type)


func _spawn_floating_number(amount: float) -> void:
	var fn := FloatingNumber.create_damage(amount, global_position)
	var parent := get_parent()
	if parent:
		parent.add_child(fn)


func die(cause: String = "unknown") -> void:
	if not is_alive:
		return
	is_alive = false
	died.emit(cause)


func _update_aggro() -> void:
	if _aggro_target:
		var u := _aggro_target as Node
		if not is_instance_valid(u) or not (u is Hero and (u as Hero).is_alive):
			_aggro_target = null
		return
	var heroes := get_tree().get_nodes_in_group("heroes")
	for node in heroes:
		var hero := node as Hero
		if hero and hero.is_alive:
			var d := global_position.distance_to(hero.global_position)
			if d <= aggro_range:
				_aggro_target = hero
				return


func _behavior_combat(_delta: float) -> void:
	if not _aggro_target:
		return
	var hero: Hero = _aggro_target as Hero
	var dist := global_position.distance_to(hero.global_position)
	if dist <= attack_range and _attack_timer <= 0.0:
		velocity = Vector2.ZERO
		_attack_timer = attack_cooldown
		hero.take_damage(attack_damage, "enemy")
	else:
		velocity = (hero.global_position - global_position).normalized() * move_speed


func _behavior_patrol(_delta: float) -> void:
	if patrol_radius <= 0.0:
		velocity = Vector2.ZERO
		return
	var to_center := _patrol_center - global_position
	if to_center.length() > patrol_radius:
		velocity = to_center.normalized() * move_speed
	else:
		# Simple wander: move perpendicular to center
		var perp := Vector2(-to_center.y, to_center.x).normalized()
		velocity = perp * move_speed * 0.5


func _draw() -> void:
	if is_alive:
		draw_circle(Vector2.ZERO, 10.0, Color(0.7, 0.15, 0.15))
		var bar_width: float = 22.0
		var bar_y: float = -16.0
		var hp_ratio := hp / max_hp
		draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width, 3.0), Color(0.2, 0.2, 0.2))
		draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width * hp_ratio, 3.0), Color(0.9, 0.2, 0.1))
	else:
		draw_circle(Vector2.ZERO, 10.0, Color(0.3, 0.2, 0.2, 0.5))


func _process(_delta: float) -> void:
	queue_redraw()
