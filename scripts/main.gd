extends Node2D
## Entry-point scene. Creates dungeon room, camera, HUD, and run-end screen.
## Handles run restart via defeat/victory screen or manual R key.

var dungeon_room: DungeonRoom
var camera: Camera2D
var run_end_screen: RunEndScreen
var _restarting: bool = false


func _ready() -> void:
	_setup_camera()
	_setup_ui()
	_start_new_room()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_run") and not _restarting:
		run_end_screen.hide_screen()
		_restart_room()


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


# -- Room lifecycle -----------------------------------------------------------

func _start_new_room() -> void:
	dungeon_room = DungeonRoom.new()
	dungeon_room.name = "DungeonRoom"
	add_child(dungeon_room)


func _restart_room() -> void:
	_restarting = true
	GameManager.reset_state()
	if dungeon_room:
		dungeon_room.queue_free()
		dungeon_room = null
	await get_tree().process_frame
	_start_new_room()
	_restarting = false


# -- Signal handlers ----------------------------------------------------------

func _on_retry_requested() -> void:
	if not _restarting:
		_restart_room()


func _on_reset_requested() -> void:
	if not _restarting:
		_restart_room()
