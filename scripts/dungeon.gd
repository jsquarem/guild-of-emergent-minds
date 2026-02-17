extends Node2D
## Dungeon run scene. One flowing world: MobRoom + BossRoom + Heroes.
## Camera follows party; when mob room is cleared, boss room activates (no scene swap).

var world: Node2D
var mob_room: DungeonRoom
var boss_room: DungeonRoom
var heroes_node: Node2D
var hero_instances: Array[Hero] = []
var camera: Camera2D
var hud: HUD
var run_end_screen: RunEndScreen
var _restarting: bool = false

const ROOM_SIZE: Vector2 = Vector2(480, 320)
const BOSS_ROOM_OFFSET: Vector2 = Vector2(480, 0)
const ROOM_TRANSITION_DELAY: float = 1.0
const CAMERA_FOLLOW_SPEED: float = 4.0
const HERO_X_OFFSETS: Array[float] = [50.0, 0.0, -50.0]  # Tank front, DPS, Healer back
const NAV_WALL_MARGIN: float = 24.0  # Margin from walls for walkable polygon


func _ready() -> void:
	_setup_camera()
	_setup_ui()
	_build_world()
	GameManager.start_run()
	EventBus.room_cleared.connect(_on_room_cleared)
	EventBus.run_ended.connect(_on_run_ended)


func _process(delta: float) -> void:
	_update_camera_follow(delta)


func _update_camera_follow(delta: float) -> void:
	if not camera:
		return
	var target_pos: Vector2
	if hero_instances.size() > 0:
		var center := Vector2.ZERO
		var count: int = 0
		for h in hero_instances:
			if h.is_alive:
				center += h.global_position
				count += 1
		if count > 0:
			center /= float(count)
			target_pos = center
		else:
			target_pos = camera.global_position
	else:
		target_pos = camera.global_position
	camera.global_position = camera.global_position.lerp(target_pos, delta * CAMERA_FOLLOW_SPEED)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_run") and not _restarting:
		run_end_screen.hide_screen()
		_restart_dungeon()


# -- Setup --------------------------------------------------------------------

func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.zoom = Vector2(1.5, 1.5)
	camera.make_current()
	add_child(camera)


func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn") as PackedScene
	hud = hud_scene.instantiate() as HUD
	hud.name = "HUD"
	canvas.add_child(hud)
	hud.restart_requested.connect(_on_retry_requested)
	hud.main_menu_requested.connect(_on_main_menu_requested)

	run_end_screen = RunEndScreen.new()
	run_end_screen.name = "RunEndScreen"
	run_end_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(run_end_screen)
	run_end_screen.retry_requested.connect(_on_retry_requested)


# -- World (one flowing dungeon) -----------------------------------------------

func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)

	mob_room = DungeonRoom.new()
	mob_room.name = "MobRoom"
	mob_room.position = Vector2.ZERO
	mob_room.room_size = ROOM_SIZE
	mob_room.is_boss_room = false
	mob_room.room_index = 0
	mob_room.region_only = true
	mob_room.door_right = true
	world.add_child(mob_room)

	boss_room = DungeonRoom.new()
	boss_room.name = "BossRoom"
	boss_room.position = BOSS_ROOM_OFFSET
	boss_room.room_size = ROOM_SIZE
	boss_room.is_boss_room = true
	boss_room.room_index = 1
	boss_room.region_only = true
	boss_room.door_left = true
	world.add_child(boss_room)

	heroes_node = Node2D.new()
	heroes_node.name = "Heroes"
	world.add_child(heroes_node)

	_build_navigation_region()
	_spawn_heroes_at(mob_room)
	hero_instances = []
	for c in heroes_node.get_children():
		if c is Hero:
			hero_instances.append(c)


func _build_navigation_region() -> void:
	var half := ROOM_SIZE / 2.0
	var margin := NAV_WALL_MARGIN
	# Mob room world x [-240,240], y [-160,160]. Boss room x [240,720]. Door at x=240, y in [-40,40].
	var ml: float = -half.x + margin
	var mr: float = half.x - margin
	var mt: float = -half.y + margin
	var mb: float = half.y - margin
	var br: float = BOSS_ROOM_OFFSET.x + half.x - margin
	var bl: float = BOSS_ROOM_OFFSET.x + margin
	var door_hi: float = 40.0
	var door_lo: float = -40.0
	# One closed outline counter-clockwise (Godot outer boundary): walkable area through door
	var outline := PackedVector2Array([
		Vector2(ml, mb), Vector2(mr, mb), Vector2(mr, door_hi), Vector2(bl, door_hi),
		Vector2(bl, mt), Vector2(br, mt), Vector2(br, door_lo), Vector2(bl, door_lo),
		Vector2(mr, door_lo), Vector2(mr, mb), Vector2(ml, mb)
	])
	var nav_region := NavigationRegion2D.new()
	nav_region.name = "NavigationRegion2D"
	var poly := NavigationPolygon.new()
	poly.add_outline(outline)
	poly.make_polygons_from_outlines()
	nav_region.navigation_polygon = poly
	world.add_child(nav_region)


func _spawn_heroes_at(room: DungeonRoom) -> void:
	var roles: Array[HeroRole] = [
		HeroRole.get_default_tank(),
		HeroRole.get_default_dps(),
		HeroRole.get_default_healer()
	]
	var base_spawn: Vector2 = room.get_world_spawn_position()
	var goal: Vector2 = room.get_world_goal_position()
	for i in range(roles.size()):
		var h := Hero.new()
		h.name = "Hero_%d" % i
		h.global_position = base_spawn + Vector2(HERO_X_OFFSETS[i], 0.0)
		h.role = roles[i]
		h.goal_position = goal
		heroes_node.add_child(h)

		var col := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 8.0
		col.shape = circle
		h.add_child(col)

		var nav_agent := NavigationAgent2D.new()
		nav_agent.name = "NavigationAgent2D"
		nav_agent.path_desired_distance = 16.0
		nav_agent.target_desired_distance = 12.0
		nav_agent.radius = 10.0
		nav_agent.avoidance_enabled = false
		h.add_child(nav_agent)

		var brain := HeroBrain.new()
		brain.name = "Brain"
		h.add_child(brain)

		h.died.connect(_on_hero_died)


func _on_hero_died(_cause: String) -> void:
	var alive_count: int = 0
	for h in hero_instances:
		if h.is_alive:
			alive_count += 1
	if alive_count <= 0:
		GameManager.fail_run()


func _activate_boss_room() -> void:
	boss_room.spawn_boss_if_deferred()
	var goal: Vector2 = boss_room.get_world_goal_position()
	for h in hero_instances:
		if not is_instance_valid(h):
			continue
		h.goal_position = goal


func _restart_dungeon() -> void:
	_restarting = true
	GameManager.reset_state()
	if world:
		world.queue_free()
		world = null
		mob_room = null
		boss_room = null
		heroes_node = null
		hero_instances.clear()
	await get_tree().process_frame
	_build_world()
	GameManager.start_run()
	_restarting = false


# -- Signal handlers ----------------------------------------------------------

func _on_run_ended(success: bool) -> void:
	if _restarting:
		return
	if not success:
		return
	for h in hero_instances:
		if is_instance_valid(h):
			h.velocity = Vector2.ZERO
	if GameManager.auto_restart_on_complete:
		_restart_dungeon()
	else:
		run_end_screen.show_victory()


func _on_room_cleared(_room_idx: int) -> void:
	var timer := get_tree().create_timer(ROOM_TRANSITION_DELAY, false)
	await timer.timeout
	_activate_boss_room()


func _on_retry_requested() -> void:
	if not _restarting:
		run_end_screen.hide_screen()
		_restart_dungeon()


func _on_main_menu_requested() -> void:
	if not _restarting:
		get_tree().change_scene_to_file("res://scenes/base.tscn")
