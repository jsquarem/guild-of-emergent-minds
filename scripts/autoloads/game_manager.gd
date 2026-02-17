extends Node
## Manages game state: speed, run lifecycle, and input actions.

enum GameState { IDLE, RUNNING, COMPLETED, FAILED }

var current_state: GameState = GameState.IDLE
var game_speed: float = 1.0
var run_count: int = 0
## When true, completing a run automatically restarts the map.
var auto_restart_on_complete: bool = true

## Set by Map when starting a run; used on completion to mark progress and grant rewards.
var current_dungeon_id: String = ""
var current_dungeon_index: int = -1

const SPEED_OPTIONS: Array[float] = [1.0, 2.0, 3.0, 4.0, 5.0]
var speed_index: int = 0


func _ready() -> void:
	var data := SaveManager.load_data()
	run_count = data.get("run_count", 0)
	EventBus.game_reset.connect(_on_game_reset)
	_setup_input_actions()


func _unhandled_input(event: InputEvent) -> void:
	for i in range(5):
		if event.is_action_pressed("speed_%d" % (i + 1)):
			set_speed(i)
			return

	if event.is_action_pressed("speed_up"):
		set_speed(mini(speed_index + 1, 4))
	elif event.is_action_pressed("speed_down"):
		set_speed(maxi(speed_index - 1, 0))


func set_speed(index: int) -> void:
	speed_index = clampi(index, 0, 4)
	game_speed = SPEED_OPTIONS[speed_index]
	Engine.time_scale = game_speed
	EventBus.speed_changed.emit(game_speed)


func start_run() -> void:
	current_state = GameState.RUNNING
	run_count += 1
	_persist_run_count()
	EventBus.run_started.emit()


func complete_run() -> void:
	if current_state != GameState.RUNNING:
		return
	current_state = GameState.COMPLETED
	_apply_dungeon_completion()
	EventBus.run_ended.emit(true)
	EventBus.dungeon_completed.emit()


func fail_run() -> void:
	if current_state != GameState.RUNNING:
		return
	current_state = GameState.FAILED
	EventBus.run_ended.emit(false)
	EventBus.dungeon_failed.emit()


func reset_state() -> void:
	current_state = GameState.IDLE


func _on_game_reset() -> void:
	var data := SaveManager.load_data()
	run_count = data.get("run_count", 0)
	current_state = GameState.IDLE
	current_dungeon_id = ""
	current_dungeon_index = -1


func _apply_dungeon_completion() -> void:
	if current_dungeon_id.is_empty():
		return
	var data: Dictionary = SaveManager.load_data()
	var completed_ids: Array = data.get("completed_dungeon_ids", [])
	if current_dungeon_id not in completed_ids:
		completed_ids.append(current_dungeon_id)
	var gold: int = data.get("gold", 0)
	var reputation: int = data.get("reputation", 0)

	var rewards: Dictionary = DungeonRegistry.get_rewards_for_index(current_dungeon_index)
	gold += rewards.get("gold", 0)
	reputation += rewards.get("reputation", 0)

	SaveManager.save_data({
		"completed_dungeon_ids": completed_ids,
		"gold": gold,
		"reputation": reputation,
	})


func _persist_run_count() -> void:
	SaveManager.save_data({"run_count": run_count})


func _setup_input_actions() -> void:
	# Speed 1x–5x (keys 1-5)
	for i in range(5):
		var action_name := "speed_%d" % (i + 1)
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			var key := InputEventKey.new()
			key.physical_keycode = (KEY_1 + i) as Key
			InputMap.action_add_event(action_name, key)

	# Speed up (+, gamepad RB)
	if not InputMap.has_action("speed_up"):
		InputMap.add_action("speed_up")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_EQUAL
		InputMap.action_add_event("speed_up", key)
		var joy := InputEventJoypadButton.new()
		joy.button_index = JOY_BUTTON_RIGHT_SHOULDER
		InputMap.action_add_event("speed_up", joy)

	# Speed down (-, gamepad LB)
	if not InputMap.has_action("speed_down"):
		InputMap.add_action("speed_down")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_MINUS
		InputMap.action_add_event("speed_down", key)
		var joy := InputEventJoypadButton.new()
		joy.button_index = JOY_BUTTON_LEFT_SHOULDER
		InputMap.action_add_event("speed_down", joy)

	# Restart run (R, gamepad Start)
	if not InputMap.has_action("restart_run"):
		InputMap.add_action("restart_run")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_R
		InputMap.action_add_event("restart_run", key)
		var joy := InputEventJoypadButton.new()
		joy.button_index = JOY_BUTTON_START
		InputMap.action_add_event("restart_run", joy)
