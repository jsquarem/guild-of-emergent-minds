extends Node2D
## Entry-point scene. Creates dungeon rooms, camera, HUD, and run-end screen.
## Manages multi-room dungeon flow: mob room -> boss room.
## Heroes persist HP between rooms. Dungeon complete only on boss kill.

var dungeon_room: DungeonRoom
var camera: Camera2D
var run_end_screen: RunEndScreen
var _restarting: bool = false
var _room_index: int = 0
var _hero_states: Array[Dictionary] = []

const ROOM_TRANSITION_DELAY: float = 1.0


func _ready() -> void:
	_setup_camera()
	_setup_ui()
	_start_dungeon()
	EventBus.room_cleared.connect(_on_room_cleared)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_run") and not _restarting:
		run_end_screen.hide_screen()
		_restart_dungeon()


# -- Setup --------------------------------------------------------------------

func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.zoom = Vector2(1.5, 1.5)
	add_child(camera)


func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn") as PackedScene
	var hud: Control = hud_scene.instantiate()
	hud.name = "HUD"
	canvas.add_child(hud)

	run_end_screen = RunEndScreen.new()
	run_end_screen.name = "RunEndScreen"
	run_end_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(run_end_screen)
	run_end_screen.retry_requested.connect(_on_retry_requested)
	run_end_screen.reset_requested.connect(_on_reset_requested)


# -- Dungeon lifecycle --------------------------------------------------------

func _start_dungeon() -> void:
	_room_index = 0
	_hero_states = []
	GameManager.start_run()
	_create_room(false)


func _create_room(is_boss: bool) -> void:
	dungeon_room = DungeonRoom.new()
	dungeon_room.name = "DungeonRoom"
	dungeon_room.is_boss_room = is_boss
	dungeon_room.room_index = _room_index
	dungeon_room.hero_states = _hero_states
	add_child(dungeon_room)


func _transition_to_boss_room() -> void:
	if dungeon_room:
		_hero_states = dungeon_room.get_hero_states()
		dungeon_room.queue_free()
		dungeon_room = null
	_room_index += 1
	await get_tree().process_frame
	_create_room(true)


func _restart_dungeon() -> void:
	_restarting = true
	GameManager.reset_state()
	if dungeon_room:
		dungeon_room.queue_free()
		dungeon_room = null
	await get_tree().process_frame
	_start_dungeon()
	_restarting = false


# -- Signal handlers ----------------------------------------------------------

func _on_room_cleared(_room_idx: int) -> void:
	# Brief pause before transitioning to boss room
	var timer := get_tree().create_timer(ROOM_TRANSITION_DELAY, false)
	await timer.timeout
	_transition_to_boss_room()


func _on_retry_requested() -> void:
	if not _restarting:
		_restart_dungeon()


func _on_reset_requested() -> void:
	if not _restarting:
		_restart_dungeon()
