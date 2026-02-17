class_name HeroTraining
extends Control
## Dedicated scene for hero training upgrades (e.g. reaction speed). Back returns to base.

const UPGRADE_COST_PER_LEVEL: int = 50

var _gold_label: Label
var _upgrade_level_label: Label
var _upgrade_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh_resources()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 24)
	add_child(vbox)

	var title := Label.new()
	title.text = "Hero training"
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	var gold_row := HBoxContainer.new()
	gold_row.add_theme_constant_override("separation", 12)
	_gold_label = Label.new()
	_gold_label.name = "GoldLabel"
	_gold_label.add_theme_font_size_override("font_size", 18)
	gold_row.add_child(_gold_label)
	vbox.add_child(gold_row)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	# Reaction speed upgrade
	var upgrade_section := Label.new()
	upgrade_section.text = "Reaction speed"
	upgrade_section.add_theme_font_size_override("font_size", 20)
	vbox.add_child(upgrade_section)

	var desc := Label.new()
	desc.text = "Faster hazard response — heroes react to telegraphed dangers more quickly."
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	vbox.add_child(desc)

	var upgrade_row := HBoxContainer.new()
	upgrade_row.add_theme_constant_override("separation", 12)
	_upgrade_level_label = Label.new()
	_upgrade_level_label.name = "UpgradeLevelLabel"
	_upgrade_level_label.add_theme_font_size_override("font_size", 16)
	upgrade_row.add_child(_upgrade_level_label)
	_upgrade_btn = Button.new()
	_upgrade_btn.name = "UpgradeButton"
	_upgrade_btn.text = "Purchase"
	_upgrade_btn.custom_minimum_size = Vector2(160, 40)
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	_style_button(_upgrade_btn, Color(0.5, 0.4, 0.7))
	upgrade_row.add_child(_upgrade_btn)
	vbox.add_child(upgrade_row)

	spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 48)
	vbox.add_child(spacer)

	var back_btn := Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "Back to base"
	back_btn.custom_minimum_size = Vector2(180, 44)
	back_btn.pressed.connect(_on_back_pressed)
	_style_button(back_btn, Color(0.45, 0.45, 0.55))
	vbox.add_child(back_btn)


func _refresh_resources() -> void:
	var data: Dictionary = SaveManager.load_data()
	var gold: int = data.get("gold", 0)
	var level: int = data.get("training_level", 0)
	_gold_label.text = "Gold: %d" % gold
	_upgrade_level_label.text = "Level %d" % level
	var cost: int = (level + 1) * UPGRADE_COST_PER_LEVEL
	_upgrade_btn.text = "Purchase (%d gold)" % cost
	_upgrade_btn.disabled = gold < cost


func _on_upgrade_pressed() -> void:
	var data: Dictionary = SaveManager.load_data()
	var gold: int = data.get("gold", 0)
	var level: int = data.get("training_level", 0)
	var cost: int = (level + 1) * UPGRADE_COST_PER_LEVEL
	if gold < cost:
		return
	SaveManager.save_data({
		"gold": gold - cost,
		"training_level": level + 1,
	})
	_refresh_resources()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/base.tscn")


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
	btn.add_theme_font_size_override("font_size", 16)
