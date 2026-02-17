class_name Hero
extends CharacterBody2D
## A single guild hero. Moves via behavior tree, tracks HP and hazard overlaps.
## If role is set, stats come from the role; otherwise uses @export defaults.

signal damaged(amount: float, source_type: String)
signal died(cause: String)
signal healed(amount: float)

@export var role: HeroRole
@export var max_hp: float = 100.0
@export var move_speed: float = 80.0

var hp: float
var is_alive: bool = true
var active_hazards: Array[Area2D] = []
var goal_position: Vector2 = Vector2.ZERO
var attack_range: float = 40.0
var attack_cooldown: float = 1.0
var attack_power: float = 10.0
var _attack_timer: float = 0.0

var heal_power: float = 0.0
var heal_range: float = 0.0
var heal_cooldown: float = 2.0
var _heal_timer: float = 0.0


func _ready() -> void:
	if role:
		max_hp = role.max_hp
		move_speed = role.move_speed
		attack_range = role.attack_range
		attack_cooldown = role.attack_cooldown
		attack_power = role.attack_power
		heal_power = role.heal_power
		heal_range = role.heal_range
		heal_cooldown = role.heal_cooldown
	hp = max_hp
	add_to_group("heroes")


func get_role_type() -> HeroRole.RoleType:
	if role:
		return role.role_type
	return HeroRole.RoleType.DPS


func get_preferred_range_distance() -> float:
	if role:
		return role.get_preferred_distance()
	return 50.0


func take_damage(amount: float, source_type: String = "unknown") -> void:
	if not is_alive:
		return
	var reduced := amount
	if role:
		reduced = maxf(0.0, amount - role.armor)
	hp -= reduced
	damaged.emit(reduced, source_type)
	EventBus.hero_damaged.emit(self, reduced, source_type)
	_spawn_floating_number(reduced, false)
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
	if not is_alive:
		return
	var actual := minf(amount, max_hp - hp)
	if actual <= 0.0:
		return
	hp += actual
	healed.emit(actual)
	_spawn_floating_number(actual, true)
	_spawn_heal_effect()


func can_attack() -> bool:
	return _attack_timer <= 0.0


func can_heal() -> bool:
	return _heal_timer <= 0.0 and heal_power > 0.0


func perform_heal(target: Hero) -> bool:
	if not can_heal() or not target or not target.is_alive:
		return false
	if target.hp >= target.max_hp:
		return false
	target.heal(heal_power)
	_heal_timer = heal_cooldown
	return true


func perform_attack(target: Node2D) -> bool:
	if not can_attack() or not target:
		return false
	if target.has_method("take_damage"):
		target.take_damage(attack_power, "hero")
		_attack_timer = attack_cooldown
		return true
	return false


func _process(delta: float) -> void:
	if is_alive:
		_attack_timer -= delta
		_heal_timer -= delta
	queue_redraw()


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


func _get_body_color() -> Color:
	if not is_alive:
		return Color(0.3, 0.3, 0.3, 0.5)
	if role:
		match role.role_type:
			HeroRole.RoleType.TANK:
				return Color(0.5, 0.35, 0.2)
			HeroRole.RoleType.DPS:
				return Color(0.9, 0.25, 0.2)
			HeroRole.RoleType.HEALER:
				return Color(0.3, 0.6, 0.9)
	return Color(0.2, 0.4, 0.9)


func _spawn_floating_number(amount: float, is_heal: bool) -> void:
	var fn: FloatingNumber
	if is_heal:
		fn = FloatingNumber.create_heal(amount, global_position)
	else:
		fn = FloatingNumber.create_damage(amount, global_position)
	var parent := get_parent()
	if parent:
		parent.add_child(fn)


func _spawn_heal_effect() -> void:
	var effect := HealEffect.new()
	add_child(effect)


func _draw() -> void:
	if is_alive:
		draw_circle(Vector2.ZERO, 8.0, _get_body_color())
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
		draw_circle(Vector2.ZERO, 8.0, _get_body_color())


