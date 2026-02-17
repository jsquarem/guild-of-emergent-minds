class_name Boss
extends CharacterBody2D
## Boss entity with phases, telegraph system, and multiple mechanics.
## Phase 4: fire-on-ground, line attack, target swap.

signal died(cause: String)

enum Phase { NORMAL, ENRAGED }
enum BossState { IDLE, MELEE, TELEGRAPH, EXECUTE }

## Stats
@export var max_hp: float = 300.0
@export var move_speed: float = 40.0
@export var attack_damage: float = 12.0
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.5
@export var aggro_range: float = 300.0

## Telegraph / ability timing
@export var telegraph_duration: float = 1.2
@export var ability_cooldown: float = 6.0
@export var enrage_hp_ratio: float = 0.5

## Mechanic tuning
@export var fire_damage_per_second: float = 40.0
@export var fire_size: Vector2 = Vector2(100, 80)
@export var fire_duration: float = 5.0
@export var line_attack_damage: float = 35.0
@export var line_attack_width: float = 30.0
@export var line_attack_length: float = 200.0
@export var target_swap_damage: float = 50.0

var hp: float
var is_alive: bool = true
var phase: Phase = Phase.NORMAL
var state: BossState = BossState.IDLE

var _attack_timer: float = 0.0
var _ability_timer: float = 3.0
var _telegraph_timer: float = 0.0
var _aggro_target: Node2D = null
var _room_node: Node2D = null

## Current ability being telegraphed / executed
var _current_ability: String = ""
var _ability_target_pos: Vector2 = Vector2.ZERO
var _ability_direction: Vector2 = Vector2.RIGHT
var _marked_target: Hero = null

## Tracks which abilities are available per phase
var _ability_pool_normal: Array[String] = ["fire"]
var _ability_pool_enraged: Array[String] = ["fire", "line_attack", "target_swap"]

## Visual tracking
var _telegraph_visual_time: float = 0.0


func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	add_to_group("bosses")


func set_room(room: Node2D) -> void:
	_room_node = room


func _physics_process(delta: float) -> void:
	if not is_alive:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_attack_timer -= delta
	_check_phase_transition()
	_update_aggro()

	match state:
		BossState.IDLE, BossState.MELEE:
			_ability_timer -= delta
			if _ability_timer <= 0.0:
				_start_telegraph()
			elif _aggro_target:
				_behavior_combat(delta)
			else:
				velocity = Vector2.ZERO
		BossState.TELEGRAPH:
			velocity = Vector2.ZERO
			_telegraph_timer -= delta
			_telegraph_visual_time += delta
			if _telegraph_timer <= 0.0:
				_execute_ability()
		BossState.EXECUTE:
			state = BossState.IDLE

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
	state = BossState.IDLE
	died.emit(cause)


# -- Phase transition ---------------------------------------------------------

func _check_phase_transition() -> void:
	if phase == Phase.NORMAL and hp / max_hp <= enrage_hp_ratio:
		phase = Phase.ENRAGED
		_ability_timer = minf(_ability_timer, 2.0)


# -- Aggro --------------------------------------------------------------------

func _update_aggro() -> void:
	if _aggro_target:
		if not is_instance_valid(_aggro_target) or not (_aggro_target is Hero and (_aggro_target as Hero).is_alive):
			_aggro_target = null
		return
	var heroes := get_tree().get_nodes_in_group("heroes")
	var best: Node2D = null
	var best_dist: float = 1e6
	for node in heroes:
		var hero := node as Hero
		if hero and hero.is_alive:
			var d := global_position.distance_to(hero.global_position)
			if d <= aggro_range and d < best_dist:
				best_dist = d
				best = hero
	_aggro_target = best


# -- Melee combat -------------------------------------------------------------

func _behavior_combat(_delta: float) -> void:
	if not _aggro_target:
		return
	var dist := global_position.distance_to(_aggro_target.global_position)
	if dist <= attack_range and _attack_timer <= 0.0:
		velocity = Vector2.ZERO
		_attack_timer = attack_cooldown
		if _aggro_target.has_method("take_damage"):
			_aggro_target.take_damage(attack_damage, "boss_melee")
	else:
		velocity = (_aggro_target.global_position - global_position).normalized() * move_speed


# -- Telegraph / Ability system -----------------------------------------------

func _start_telegraph() -> void:
	var pool: Array[String] = _ability_pool_enraged if phase == Phase.ENRAGED else _ability_pool_normal
	_current_ability = pool[randi() % pool.size()]
	state = BossState.TELEGRAPH
	_telegraph_timer = telegraph_duration
	_telegraph_visual_time = 0.0

	var cd_multiplier: float = 0.7 if phase == Phase.ENRAGED else 1.0
	_ability_timer = ability_cooldown * cd_multiplier

	match _current_ability:
		"fire":
			_prepare_fire_telegraph()
		"line_attack":
			_prepare_line_telegraph()
		"target_swap":
			_prepare_target_swap_telegraph()

	var data: Dictionary = _build_telegraph_data()
	EventBus.mechanic_telegraph.emit(_current_ability, data)


func _prepare_fire_telegraph() -> void:
	if _aggro_target and is_instance_valid(_aggro_target):
		_ability_target_pos = _aggro_target.global_position
	else:
		_ability_target_pos = global_position + Vector2(randf_range(-60, 60), randf_range(-60, 60))


func _prepare_line_telegraph() -> void:
	if _aggro_target and is_instance_valid(_aggro_target):
		_ability_direction = (_aggro_target.global_position - global_position).normalized()
	else:
		_ability_direction = Vector2.RIGHT.rotated(randf() * TAU)
	_ability_target_pos = global_position


func _prepare_target_swap_telegraph() -> void:
	var heroes := get_tree().get_nodes_in_group("heroes")
	var alive_heroes: Array[Hero] = []
	for node in heroes:
		var h := node as Hero
		if h and h.is_alive:
			alive_heroes.append(h)
	if alive_heroes.is_empty():
		_current_ability = "fire"
		_prepare_fire_telegraph()
		return
	# Pick a hero that is NOT the current aggro target if possible
	var candidates: Array[Hero] = []
	for h in alive_heroes:
		if h != _aggro_target:
			candidates.append(h)
	if candidates.is_empty():
		candidates = alive_heroes
	_marked_target = candidates[randi() % candidates.size()]
	_ability_target_pos = _marked_target.global_position


func _build_telegraph_data() -> Dictionary:
	var data: Dictionary = {
		"position": _ability_target_pos,
		"duration": telegraph_duration,
	}
	match _current_ability:
		"fire":
			data["extent"] = fire_size
		"line_attack":
			data["direction"] = _ability_direction
			data["extent"] = Vector2(line_attack_length, line_attack_width)
		"target_swap":
			data["target"] = _marked_target
	return data


# -- Execute abilities --------------------------------------------------------

func _execute_ability() -> void:
	state = BossState.EXECUTE

	var data: Dictionary = _build_telegraph_data()
	EventBus.mechanic_triggered.emit(_current_ability, data)

	match _current_ability:
		"fire":
			_execute_fire()
		"line_attack":
			_execute_line_attack()
		"target_swap":
			_execute_target_swap()

	_current_ability = ""
	_marked_target = null


func _execute_fire() -> void:
	var parent: Node2D = _room_node if _room_node else get_parent()
	var fire := FireHazard.new()
	fire.name = "BossFire"
	fire.position = _ability_target_pos
	fire.hazard_size = fire_size
	fire.damage_per_second = fire_damage_per_second
	parent.add_child(fire)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = fire_size
	col.shape = rect
	fire.add_child(col)

	# Auto-remove fire after duration
	var timer := fire.get_tree().create_timer(fire_duration, false)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(fire):
			fire.queue_free()
	)


func _execute_line_attack() -> void:
	var start_pos: Vector2 = global_position
	var end_pos: Vector2 = start_pos + _ability_direction * line_attack_length
	var half_width: float = line_attack_width / 2.0
	var heroes := get_tree().get_nodes_in_group("heroes")
	for node in heroes:
		var hero := node as Hero
		if not hero or not hero.is_alive:
			continue
		var dist := _point_to_segment_distance(hero.global_position, start_pos, end_pos)
		if dist <= half_width:
			hero.take_damage(line_attack_damage, "line_attack")


func _execute_target_swap() -> void:
	if _marked_target and is_instance_valid(_marked_target) and _marked_target.is_alive:
		_marked_target.take_damage(target_swap_damage, "target_swap")
		_aggro_target = _marked_target


# -- Helpers ------------------------------------------------------------------

func _point_to_segment_distance(point: Vector2, seg_start: Vector2, seg_end: Vector2) -> float:
	var seg := seg_end - seg_start
	var seg_len_sq := seg.length_squared()
	if seg_len_sq < 0.001:
		return point.distance_to(seg_start)
	var t := clampf((point - seg_start).dot(seg) / seg_len_sq, 0.0, 1.0)
	var projection := seg_start + seg * t
	return point.distance_to(projection)


# -- Drawing ------------------------------------------------------------------

func _draw() -> void:
	if not is_alive:
		draw_circle(Vector2.ZERO, 16.0, Color(0.3, 0.1, 0.1, 0.4))
		return

	# Body — larger than regular enemies, color shifts on enrage
	var body_color: Color
	if phase == Phase.ENRAGED:
		body_color = Color(0.85, 0.15, 0.5)
	else:
		body_color = Color(0.6, 0.1, 0.1)
	draw_circle(Vector2.ZERO, 16.0, body_color)

	# Crown / boss indicator
	draw_circle(Vector2(0, -20), 4.0, Color(1.0, 0.85, 0.2))

	# HP bar
	var bar_width: float = 36.0
	var bar_y: float = -28.0
	var hp_ratio := hp / max_hp
	draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width, 4.0), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width * hp_ratio, 4.0), Color(0.8, 0.1, 0.1))

	# Telegraph visuals
	if state == BossState.TELEGRAPH:
		_draw_telegraph()


func _draw_telegraph() -> void:
	var alpha: float = 0.3 + 0.2 * sin(_telegraph_visual_time * 8.0)
	match _current_ability:
		"fire":
			var local_pos: Vector2 = _ability_target_pos - global_position
			var rect := Rect2(local_pos - fire_size / 2.0, fire_size)
			draw_rect(rect, Color(1.0, 0.5, 0.0, alpha))
			draw_rect(rect, Color(1.0, 0.7, 0.0, alpha + 0.2), false, 2.0)
		"line_attack":
			var start_local := Vector2.ZERO
			var end_local := _ability_direction * line_attack_length
			draw_line(start_local, end_local, Color(1.0, 0.2, 0.2, alpha + 0.2), line_attack_width, true)
			draw_line(start_local, end_local, Color(1.0, 0.4, 0.4, alpha), 2.0)
		"target_swap":
			if _marked_target and is_instance_valid(_marked_target):
				var local_pos: Vector2 = _marked_target.global_position - global_position
				draw_circle(local_pos, 14.0, Color(0.9, 0.1, 0.9, alpha))
				draw_arc(local_pos, 16.0, 0.0, TAU, 24, Color(1.0, 0.3, 1.0, alpha + 0.2), 2.0)


func _process(_delta: float) -> void:
	queue_redraw()
