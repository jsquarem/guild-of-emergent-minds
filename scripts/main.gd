extends Node2D
## Project entry point. Title/start screen with "Start game" and "Reset Progress" (with confirmation).

var _main_vbox: VBoxContainer
var _confirm_vbox: VBoxContainer

func _ready() -> void:
	_build_title_ui()


func _build_title_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)

	_main_vbox = VBoxContainer.new()
	_main_vbox.name = "MainVBox"
	_main_vbox.add_theme_constant_override("separation", 32)
	center.add_child(_main_vbox)

	var title := Label.new()
	title.name = "Title"
	title.text = "Guild of Emergent Minds"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_vbox.add_child(title)

	var start_btn := Button.new()
	start_btn.name = "StartGameButton"
	start_btn.text = "Start game"
	start_btn.custom_minimum_size = Vector2(220, 52)
	start_btn.pressed.connect(_on_start_game_pressed)
	_style_button(start_btn, Color(0.2, 0.6, 0.35))
	_main_vbox.add_child(start_btn)

	var reset_btn := Button.new()
	reset_btn.name = "ResetProgressButton"
	reset_btn.text = "Reset Progress"
	reset_btn.custom_minimum_size = Vector2(220, 52)
	reset_btn.pressed.connect(_on_reset_pressed)
	_style_button(reset_btn, Color(0.8, 0.3, 0.2))
	_main_vbox.add_child(reset_btn)

	# Confirmation (hidden by default)
	_confirm_vbox = VBoxContainer.new()
	_confirm_vbox.name = "ConfirmVBox"
	_confirm_vbox.add_theme_constant_override("separation", 24)
	_confirm_vbox.visible = false
	center.add_child(_confirm_vbox)

	var confirm_label := Label.new()
	confirm_label.text = "Wipe all unlocks and progress?"
	confirm_label.add_theme_font_size_override("font_size", 20)
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_vbox.add_child(confirm_label)

	var confirm_row := HBoxContainer.new()
	confirm_row.add_theme_constant_override("separation", 16)
	var yes_btn := Button.new()
	yes_btn.text = "Yes"
	yes_btn.custom_minimum_size = Vector2(100, 44)
	yes_btn.pressed.connect(_on_confirm_reset_yes)
	_style_button(yes_btn, Color(0.9, 0.2, 0.2))
	confirm_row.add_child(yes_btn)
	var no_btn := Button.new()
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(100, 44)
	no_btn.pressed.connect(_on_confirm_reset_no)
	_style_button(no_btn, Color(0.5, 0.5, 0.55))
	confirm_row.add_child(no_btn)
	_confirm_vbox.add_child(confirm_row)


func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/base.tscn")


func _on_reset_pressed() -> void:
	_main_vbox.visible = false
	_confirm_vbox.visible = true


func _on_confirm_reset_yes() -> void:
	SaveManager.reset_to_default()
	EventBus.game_reset.emit()
	_confirm_vbox.visible = false
	_main_vbox.visible = true


func _on_confirm_reset_no() -> void:
	_confirm_vbox.visible = false
	_main_vbox.visible = true


func _style_button(btn: Button, color: Color) -> void:
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = color.darkened(0.3)
	style_normal.border_color = color
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(6)
	style_normal.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", style_normal)
	var style_hover := style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = color.darkened(0.1)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_font_size_override("font_size", 20)
