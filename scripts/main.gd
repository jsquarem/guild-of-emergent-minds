extends Node2D
## Entry-point scene. Creates dungeon room, camera, and HUD.
## Handles run restart on death / completion.

var dungeon_room: DungeonRoom
var camera: Camera2D
var _restarting: bool = false


func _ready() -> void:
	_setup_camera()
	_setup_hud()
	_start_new_room()
	EventBus.run_ended.connect(_on_run_ended)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_run") and not _restarting:
		_restart_room()


# -- Setup --------------------------------------------------------------------

func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.zoom = Vector2(1.5, 1.5)
	add_child(camera)


func _setup_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn") as PackedScene
	var hud: Control = hud_scene.instantiate()
	hud.name = "HUD"
	canvas.add_child(hud)


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
	# Wait one frame for queue_free, then create new room
	await get_tree().process_frame
	_start_new_room()
	_restarting = false


func _on_run_ended(_success: bool) -> void:
	if _restarting:
		return
	# Brief real-time pause before auto-restart (ignores time scale)
	var timer := get_tree().create_timer(2.5, true, false, true)
	await timer.timeout
	_restart_room()
