class_name Base
extends Control
## Guild hub: select dungeon (opens Map), hero training (dedicated scene), display gold/reputation.

var _gold_label: Label
var _rep_label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh_resources()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 24)
	add_child(vbox)

	var resources_row := HBoxContainer.new()
	resources_row.add_theme_constant_override("separation", 24)
	_gold_label = Label.new()
	_gold_label.name = "GoldLabel"
	_gold_label.add_theme_font_size_override("font_size", 18)
	resources_row.add_child(_gold_label)
	_rep_label = Label.new()
	_rep_label.name = "ReputationLabel"
	_rep_label.add_theme_font_size_override("font_size", 18)
	resources_row.add_child(_rep_label)
	vbox.add_child(resources_row)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)

	var select_btn := Button.new()
	select_btn.name = "SelectDungeonButton"
	select_btn.text = "Select dungeon"
	select_btn.custom_minimum_size = Vector2(200, 48)
	select_btn.pressed.connect(_on_select_dungeon_pressed)
	_style_button(select_btn, Color(0.2, 0.6, 0.35))
	vbox.add_child(select_btn)

	var training_btn := Button.new()
	training_btn.name = "HeroTrainingButton"
	training_btn.text = "Hero training"
	training_btn.custom_minimum_size = Vector2(200, 48)
	training_btn.pressed.connect(_on_hero_training_pressed)
	_style_button(training_btn, Color(0.5, 0.4, 0.7))
	vbox.add_child(training_btn)

	var main_menu_btn := Button.new()
	main_menu_btn.name = "MainMenuButton"
	main_menu_btn.text = "Main menu"
	main_menu_btn.custom_minimum_size = Vector2(200, 48)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)
	_style_button(main_menu_btn, Color(0.45, 0.45, 0.55))
	vbox.add_child(main_menu_btn)


func _refresh_resources() -> void:
	var data: Dictionary = SaveManager.load_data()
	var gold: int = data.get("gold", 0)
	var reputation: int = data.get("reputation", 0)
	_gold_label.text = "Gold: %d" % gold
	_rep_label.text = "Reputation: %d" % reputation


func _on_select_dungeon_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/map.tscn")


func _on_hero_training_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/hero_training.tscn")


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


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
	btn.add_theme_font_size_override("font_size", 18)
