class_name RunEndScreen
extends Control
## Full-screen overlay shown on run end (defeat or victory).
## Buttons: Retry, Reset Progress. Emits signals for Main to handle.

signal retry_requested()
signal reset_requested()

var _title_label: Label
var _message_label: Label
var _stats_label: Label
var _btn_row: HBoxContainer
var _retry_button: Button
var _reset_button: Button
var _confirm_container: HBoxContainer
var _confirm_label: Label
var _confirm_yes: Button
var _confirm_no: Button
var _bg: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.game_reset.connect(_on_game_reset)


func _build_ui() -> void:
	# Full-screen dark overlay
	_bg = ColorRect.new()
	_bg.color = Color(0.0, 0.0, 0.0, 0.75)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 240)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel_style.border_color = Color(0.4, 0.35, 0.5)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_title_label)

	# Message
	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 14)
	_message_label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	vbox.add_child(_message_label)

	# Stats
	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 12)
	_stats_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	vbox.add_child(_stats_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	# Buttons row
	_btn_row = HBoxContainer.new()
	_btn_row.add_theme_constant_override("separation", 16)
	_btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_btn_row)

	_retry_button = _make_button("Retry", Color(0.2, 0.7, 0.3))
	_retry_button.pressed.connect(_on_retry_pressed)
	_btn_row.add_child(_retry_button)

	_reset_button = _make_button("Reset Progress", Color(0.8, 0.3, 0.2))
	_reset_button.pressed.connect(_on_reset_pressed)
	_btn_row.add_child(_reset_button)

	# Confirmation row (hidden by default)
	_confirm_container = HBoxContainer.new()
	_confirm_container.add_theme_constant_override("separation", 8)
	_confirm_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirm_container.visible = false
	vbox.add_child(_confirm_container)

	_confirm_label = Label.new()
	_confirm_label.text = "Wipe all unlocks and progress?"
	_confirm_label.add_theme_font_size_override("font_size", 13)
	_confirm_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	_confirm_container.add_child(_confirm_label)

	_confirm_yes = _make_button("Yes", Color(0.9, 0.2, 0.2))
	_confirm_yes.pressed.connect(_on_confirm_reset)
	_confirm_container.add_child(_confirm_yes)

	_confirm_no = _make_button("No", Color(0.5, 0.5, 0.55))
	_confirm_no.pressed.connect(_on_cancel_reset)
	_confirm_container.add_child(_confirm_no)


func show_defeat() -> void:
	_title_label.text = "DEFEAT"
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	_message_label.text = "Your party has been wiped."
	_stats_label.visible = true
	_btn_row.visible = true
	_update_stats()
	_confirm_container.visible = false
	visible = true


func show_victory() -> void:
	_title_label.text = "VICTORY"
	_title_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.35))
	_message_label.text = "All enemies defeated!"
	_stats_label.visible = true
	_btn_row.visible = true
	_update_stats()
	_confirm_container.visible = false
	visible = true


func hide_screen() -> void:
	visible = false
	_confirm_container.visible = false
	_btn_row.visible = true


## Show only the reset-progression confirmation (e.g. from HUD button).
func show_reset_progression_confirm() -> void:
	_title_label.text = "Reset progression?"
	_message_label.text = "Wipe all unlocks and progress?"
	_stats_label.visible = false
	_btn_row.visible = false
	_confirm_container.visible = true
	visible = true


func _update_stats() -> void:
	var lines: Array[String] = []
	lines.append("Run: %d" % GameManager.run_count)
	var fire_deaths: int = UnlockManager.get_death_count("fire")
	var line_deaths: int = UnlockManager.get_death_count("line_attack")
	var swap_deaths: int = UnlockManager.get_death_count("target_swap")
	lines.append("Deaths -- Fire: %d  Line: %d  Swap: %d" % [fire_deaths, line_deaths, swap_deaths])
	var unlocks: Array[String] = []
	if UnlockManager.is_unlocked("avoid_fire"):
		unlocks.append("Avoid Fire")
	if unlocks.is_empty():
		lines.append("Unlocks: (none)")
	else:
		lines.append("Unlocks: %s" % ", ".join(unlocks))
	_stats_label.text = "\n".join(lines)


# -- Button handlers ----------------------------------------------------------

func _on_retry_pressed() -> void:
	hide_screen()
	retry_requested.emit()


func _on_reset_pressed() -> void:
	_confirm_container.visible = true


func _on_confirm_reset() -> void:
	_confirm_container.visible = false
	_btn_row.visible = true
	_stats_label.visible = true
	SaveManager.reset_to_default()
	EventBus.game_reset.emit()
	_update_stats()
	reset_requested.emit()


func _on_cancel_reset() -> void:
	_confirm_container.visible = false
	_btn_row.visible = true
	_stats_label.visible = true
	visible = false


# -- EventBus handlers --------------------------------------------------------

func _on_run_ended(success: bool) -> void:
	if success:
		# Victory splash kept for later; skip showing for now
		pass
	else:
		show_defeat()


func _on_game_reset() -> void:
	_update_stats()


# -- Helpers ------------------------------------------------------------------

func _make_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120, 36)
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = color.darkened(0.3)
	style_normal.border_color = color
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(4)
	style_normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", style_normal)
	var style_hover := style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = color.darkened(0.1)
	btn.add_theme_stylebox_override("hover", style_hover)
	var style_pressed := style_normal.duplicate() as StyleBoxFlat
	style_pressed.bg_color = color.darkened(0.5)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_font_size_override("font_size", 14)
	return btn
