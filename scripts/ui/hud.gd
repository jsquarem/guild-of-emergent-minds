class_name HUD
extends Control
## Heads-up display: hero HP, speed indicator, run count, unlock notifications.

var hp_label: Label
var speed_label: Label
var run_label: Label
var death_label: Label
var notification_label: Label

var _notification_timer: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_connect_signals()


func _process(delta: float) -> void:
	_update_hero_hp()
	_update_death_counts()
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	_tick_notification(real_delta)


# -- UI construction ----------------------------------------------------------

func _build_ui() -> void:
	# Top-left panel
	var top_left := VBoxContainer.new()
	top_left.position = Vector2(16, 16)
	add_child(top_left)

	hp_label = _make_label("HP: --/--", 18)
	top_left.add_child(hp_label)

	run_label = _make_label("Run: 0", 14)
	top_left.add_child(run_label)

	death_label = _make_label("Fire deaths: 0", 14)
	top_left.add_child(death_label)

	# Top-right: speed
	speed_label = _make_label("Speed: 1x", 18)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	speed_label.offset_left = -140.0
	speed_label.offset_top = 16.0
	speed_label.offset_right = -16.0
	add_child(speed_label)

	# Center-top: notifications
	notification_label = _make_label("", 24)
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	notification_label.offset_left = -220.0
	notification_label.offset_top = 80.0
	notification_label.offset_right = 220.0
	add_child(notification_label)

	# Bottom-center: controls hint
	var hint := _make_label("[1-5] Speed  |  [+/-] or LB/RB  |  [R] Restart", 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -32.0
	add_child(hint)


func _make_label(text: String, size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	return lbl


# -- Signal handlers ----------------------------------------------------------

func _connect_signals() -> void:
	EventBus.speed_changed.connect(_on_speed_changed)
	EventBus.behavior_unlocked.connect(_on_behavior_unlocked)
	EventBus.run_started.connect(_on_run_started)
	EventBus.run_ended.connect(_on_run_ended)


func _on_speed_changed(new_speed: float) -> void:
	speed_label.text = "Speed: %dx" % int(new_speed)


func _on_behavior_unlocked(behavior_id: String) -> void:
	_show_notification(
		"BEHAVIOR UNLOCKED: %s" % behavior_id.replace("_", " ").to_upper(),
		Color(1.0, 0.85, 0.1),
		5.0
	)


func _on_run_started() -> void:
	run_label.text = "Run: %d" % GameManager.run_count


func _on_run_ended(success: bool) -> void:
	if success:
		_show_notification("DUNGEON COMPLETE!", Color(0.2, 1.0, 0.3), 3.0)
	else:
		_show_notification("HERO DEFEATED", Color(1.0, 0.25, 0.2), 3.0)


# -- Live updates -------------------------------------------------------------

func _update_hero_hp() -> void:
	var heroes := get_tree().get_nodes_in_group("heroes")
	if heroes.size() > 0:
		var hero: Hero = heroes[0]
		hp_label.text = "HP: %d / %d" % [ceili(hero.hp), int(hero.max_hp)]
	else:
		hp_label.text = "HP: --/--"


func _update_death_counts() -> void:
	var fire_deaths: int = UnlockManager.get_death_count("fire")
	var unlocked: bool = UnlockManager.is_unlocked("avoid_fire")
	if unlocked:
		death_label.text = "Fire deaths: %d  [AVOID FIRE unlocked]" % fire_deaths
	else:
		death_label.text = "Fire deaths: %d / %d to unlock" % [fire_deaths, 3]


func _show_notification(text: String, color: Color, duration: float) -> void:
	notification_label.text = text
	notification_label.add_theme_color_override("font_color", color)
	_notification_timer = duration


func _tick_notification(real_delta: float) -> void:
	if _notification_timer > 0.0:
		_notification_timer -= real_delta
		if _notification_timer <= 0.0:
			notification_label.text = ""
