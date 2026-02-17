class_name DungeonRoom
extends Node2D
## A single dungeon room. Creates floor, walls, fire hazard, goal zone, and
## spawns a hero. All geometry is built programmatically (placeholder shapes).

@export var room_size: Vector2 = Vector2(480, 320)

var hero_instance: Hero
var goal_zone: Area2D


func _ready() -> void:
	_create_walls()
	_create_goal_zone()
	_create_fire_hazard()
	_spawn_hero()
	GameManager.start_run()


# -- Room construction --------------------------------------------------------

func _create_walls() -> void:
	var wall_body := StaticBody2D.new()
	wall_body.name = "Walls"
	add_child(wall_body)

	var half := room_size / 2.0
	var t := 8.0  # wall thickness

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


func _spawn_hero() -> void:
	hero_instance = Hero.new()
	hero_instance.name = "Hero"
	hero_instance.position = Vector2(-room_size.x / 2.0 + 40.0, 0.0)
	hero_instance.goal_position = goal_zone.position
	add_child(hero_instance)

	# Collision shape
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	col.shape = circle
	hero_instance.add_child(col)

	# AI brain
	var brain := HeroBrain.new()
	brain.name = "Brain"
	hero_instance.add_child(brain)

	hero_instance.died.connect(_on_hero_died)


# -- Signals ------------------------------------------------------------------

func _on_goal_entered(body: Node2D) -> void:
	if body is Hero:
		GameManager.complete_run()


func _on_hero_died(_cause: String) -> void:
	GameManager.fail_run()


# -- Drawing (walls + goal visual) -------------------------------------------

func _draw() -> void:
	var half := room_size / 2.0
	var t := 8.0

	# Floor
	draw_rect(Rect2(-half, room_size), Color(0.12, 0.12, 0.18))

	# Wall outlines
	var wall_color := Color(0.3, 0.3, 0.35)
	draw_rect(Rect2(-half.x - t, -half.y - t / 2.0, room_size.x + t * 2.0, t), wall_color)
	draw_rect(Rect2(-half.x - t, half.y - t / 2.0, room_size.x + t * 2.0, t), wall_color)
	draw_rect(Rect2(-half.x - t / 2.0, -half.y, t, room_size.y), wall_color)
	draw_rect(Rect2(half.x - t / 2.0, -half.y, t, room_size.y), wall_color)

	# Goal zone glow
	if goal_zone:
		draw_circle(goal_zone.position, 22.0, Color(0.1, 0.8, 0.2, 0.25))
		draw_arc(goal_zone.position, 20.0, 0.0, TAU, 32, Color(0.2, 1.0, 0.3, 0.8), 2.0)
