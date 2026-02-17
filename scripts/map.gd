extends Control
## Map scene: dungeons along a path; select from open dungeons and start run.

var _selected_index: int = -1
var _dungeon_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var data: Dictionary = SaveManager.load_data()
	var completed: int = data.get("completed_dungeon_count", 0)
	var path_size: int = DungeonRegistry.get_path_size()

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	var title := Label.new()
	title.text = "Select dungeon"
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	# Path: horizontal row of dungeon nodes
	var path_row := HBoxContainer.new()
	path_row.add_theme_constant_override("separation", 20)
	_dungeon_buttons.clear()
	for i in range(path_size):
		var d: Dictionary = DungeonRegistry.get_dungeon_at_index(i)
		var name_str: String = d.get("display_name", "Dungeon %d" % (i + 1))
		var open: bool = i <= completed
		var btn := Button.new()
		btn.text = name_str if open else (name_str + " (locked)")
		btn.disabled = not open
		btn.custom_minimum_size = Vector2(140, 44)
		btn.pressed.connect(_on_dungeon_pressed.bind(i))
		_style_button(btn, Color(0.25, 0.5, 0.7) if open else Color(0.3, 0.3, 0.35))
		path_row.add_child(btn)
		_dungeon_buttons.append(btn)
	vbox.add_child(path_row)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)

	var start_btn := Button.new()
	start_btn.name = "StartRunButton"
	start_btn.text = "Start run"
	start_btn.custom_minimum_size = Vector2(160, 44)
	start_btn.pressed.connect(_on_start_run_pressed)
	_style_button(start_btn, Color(0.2, 0.65, 0.3))
	btn_row.add_child(start_btn)

	var back_btn := Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(120, 44)
	back_btn.pressed.connect(_on_back_pressed)
	_style_button(back_btn, Color(0.45, 0.45, 0.55))
	btn_row.add_child(back_btn)

	vbox.add_child(btn_row)


func _on_dungeon_pressed(index: int) -> void:
	_selected_index = index
	_update_selection_visual()


func _update_selection_visual() -> void:
	for i in range(_dungeon_buttons.size()):
		var btn: Button = _dungeon_buttons[i]
		if i == _selected_index:
			btn.modulate = Color(1.2, 1.2, 1.2)
		else:
			btn.modulate = Color.WHITE


func _on_start_run_pressed() -> void:
	if _selected_index < 0:
		return
	var d: Dictionary = DungeonRegistry.get_dungeon_at_index(_selected_index)
	GameManager.current_dungeon_id = d.get("id", "")
	GameManager.current_dungeon_index = _selected_index
	get_tree().change_scene_to_file("res://scenes/dungeon.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/base.tscn")


func _style_button(btn: Button, color: Color) -> void:
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
	btn.add_theme_stylebox_override("disabled", style_normal)
	btn.add_theme_font_size_override("font_size", 14)
