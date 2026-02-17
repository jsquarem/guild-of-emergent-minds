class_name DungeonRoom
extends Node2D
## A single dungeon room. Creates floor, walls, heroes and enemies/boss.
## Set is_boss_room and room_index before adding to tree.
## Pass hero_states to carry hero HP across rooms.

@export var room_size: Vector2 = Vector2(480, 320)
@export var is_boss_room: bool = false
@export var room_index: int = 0

## Optional: carry hero HP from previous room. Array of {role: HeroRole, hp: float}
var hero_states: Array[Dictionary] = []

var hero_instances: Array[Hero] = []
var goal_zone: Area2D
var boss_instance: Boss = null
var _hero_died_count: int = 0
var _enemy_died_count: int = 0
var _total_enemies: int = 0


func _ready() -> void:
	_create_walls()
	if is_boss_room:
		_create_goal_zone()
	_spawn_heroes()
	if is_boss_room:
		_spawn_boss()
	else:
		_spawn_enemies()


# -- Room construction --------------------------------------------------------

func _create_walls() -> void:
	var wall_body := StaticBody2D.new()
	wall_body.name = "Walls"
	add_child(wall_body)

	var half := room_size / 2.0
	var t := 8.0

	_add_wall_segment(wall_body, Vector2(0, -half.y), Vector2(room_size.x + t * 2, t))
	_add_wall_segment(wall_body, Vector2(0, half.y), Vector2(room_size.x + t * 2, t))
	_add_wall_segment(wall_body, Vector2(-half.x, 0), Vector2(t, room_size.y))
	_add_wall_segment(wall_body, Vector2(half.x, 0), Vector2(t, room_size.y))


func _add_wall_segment(parent: StaticBody2D, pos: Vector2, size: Vector2) -> void:
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	col.position = pos
	parent.add_child(col)


func _create_goal_zone() -> void:
	goal_zone = Area2D.new()
	goal_zone.name = "GoalZone"
	goal_zone.position = Vector2(room_size.x / 2.0 - 40.0, 0.0)
	goal_zone.collision_layer = 0
	goal_zone.collision_mask = 1
	goal_zone.monitoring = true
	goal_zone.monitorable = false
	add_child(goal_zone)

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	col.shape = circle
	goal_zone.add_child(col)

	goal_zone.body_entered.connect(_on_goal_entered)


func _create_fire_hazard() -> void:
	## Environmental fire hazard (not used by boss). Keep for future use.
	var fire := FireHazard.new()
	fire.name = "FireHazard"
	fire.position = Vector2.ZERO
	fire.hazard_size = Vector2(200, 120)
	fire.damage_per_second = 50.0
	add_child(fire)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = fire.hazard_size
	col.shape = rect
	fire.add_child(col)


func _spawn_heroes() -> void:
	var roles: Array[HeroRole] = [
		HeroRole.get_default_tank(),
		HeroRole.get_default_dps(),
		HeroRole.get_default_healer()
	]
	var x_offsets: Array[float] = [-50.0, 0.0, 50.0]
	for i in range(roles.size()):
		var h := Hero.new()
		h.name = "Hero_%d" % i
		h.position = Vector2(-room_size.x / 2.0 + 60.0 + x_offsets[i], 0.0)
		h.role = roles[i]
		if goal_zone:
			h.goal_position = goal_zone.position
		else:
			h.goal_position = Vector2(room_size.x / 2.0 - 40.0, 0.0)
		add_child(h)

		# Restore HP from previous room if available
		if i < hero_states.size():
			h.hp = hero_states[i].get("hp", h.max_hp)

		var col := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 8.0
		col.shape = circle
		h.add_child(col)

		var brain := HeroBrain.new()
		brain.name = "Brain"
		h.add_child(brain)

		h.died.connect(_on_hero_died)
		hero_instances.append(h)


func _spawn_boss() -> void:
	boss_instance = Boss.new()
	boss_instance.name = "Boss"
	boss_instance.position = Vector2(room_size.x / 4.0, 0.0)
	boss_instance.set_room(self)
	add_child(boss_instance)
	_total_enemies = 1

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	col.shape = circle
	boss_instance.add_child(col)

	boss_instance.died.connect(_on_enemy_died)


func _spawn_enemies() -> void:
	var e1 := Enemy.new()
	e1.name = "Enemy1"
	e1.position = Vector2(room_size.x / 4.0, -room_size.y / 4.0)
	e1.max_hp = 25.0
	e1.attack_damage = 8.0
	e1.aggro_range = 140.0
	e1.patrol_radius = 0.0
	add_child(e1)
	_add_enemy_collision(e1)
	e1.died.connect(_on_enemy_died)

	var e2 := Enemy.new()
	e2.name = "Enemy2"
	e2.position = Vector2(room_size.x / 4.0, room_size.y / 4.0)
	e2.max_hp = 30.0
	e2.patrol_radius = 40.0
	add_child(e2)
	_add_enemy_collision(e2)
	e2.died.connect(_on_enemy_died)

	_total_enemies = 2


func _add_enemy_collision(enemy: Enemy) -> void:
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	col.shape = circle
	enemy.add_child(col)


## Returns current hero states for carrying to the next room.
func get_hero_states() -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for h in hero_instances:
		states.append({
			"role": h.role,
			"hp": h.hp,
			"is_alive": h.is_alive,
		})
	return states


# -- Signals ------------------------------------------------------------------

func _on_goal_entered(body: Node2D) -> void:
	if body is Hero:
		GameManager.complete_run()


func _on_hero_died(_cause: String) -> void:
	_hero_died_count += 1
	if _hero_died_count >= hero_instances.size():
		GameManager.fail_run()


func _on_enemy_died(_cause: String) -> void:
	_enemy_died_count += 1
	if _enemy_died_count >= _total_enemies:
		if is_boss_room:
			GameManager.complete_run()
		else:
			EventBus.room_cleared.emit(room_index)


# -- Drawing (walls + goal visual) -------------------------------------------

func _draw() -> void:
	var half := room_size / 2.0
	var t := 8.0

	# Floor -- slightly different tint for boss room
	var floor_color := Color(0.15, 0.1, 0.12) if is_boss_room else Color(0.12, 0.12, 0.18)
	draw_rect(Rect2(-half, room_size), floor_color)

	# Wall outlines
	var wall_color := Color(0.4, 0.25, 0.25) if is_boss_room else Color(0.3, 0.3, 0.35)
	draw_rect(Rect2(-half.x - t, -half.y - t / 2.0, room_size.x + t * 2.0, t), wall_color)
	draw_rect(Rect2(-half.x - t, half.y - t / 2.0, room_size.x + t * 2.0, t), wall_color)
	draw_rect(Rect2(-half.x - t / 2.0, -half.y, t, room_size.y), wall_color)
	draw_rect(Rect2(half.x - t / 2.0, -half.y, t, room_size.y), wall_color)

	# Goal zone glow (boss room only)
	if goal_zone:
		draw_circle(goal_zone.position, 22.0, Color(0.1, 0.8, 0.2, 0.25))
		draw_arc(goal_zone.position, 20.0, 0.0, TAU, 32, Color(0.2, 1.0, 0.3, 0.8), 2.0)
