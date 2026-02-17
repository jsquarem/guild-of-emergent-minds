class_name HUD
extends Control
## Heads-up display: party panel (heroes + stats), enemies window (stats), speed, notifications.
## Layout is in scenes/ui/hud.tscn so you can edit positions and labels in the Godot editor.

@onready var party_panel: PanelContainer = $PartyPanel
@onready var party_list: VBoxContainer = $PartyPanel/PartyMargin/PartyVBox/PartyList
@onready var run_label: Label = $PartyPanel/PartyMargin/PartyVBox/RunRow/RunLabel
@onready var death_label: Label = $PartyPanel/PartyMargin/PartyVBox/RunRow/DeathLabel
@onready var enemies_panel: PanelContainer = $EnemiesPanel
@onready var enemies_list: VBoxContainer = $EnemiesPanel/EnemiesMargin/EnemiesVBox/EnemiesList
@onready var speed_label: Label = $SpeedLabel
@onready var notification_label: Label = $NotificationLabel

var _notification_timer: float = 0.0
const ROW_SPACING: int = 4


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_panel_styles()
	_connect_signals()


func _process(delta: float) -> void:
	_update_party_panel()
	_update_enemies_panel()
	_update_death_counts()
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	_tick_notification(real_delta)


func _apply_panel_styles() -> void:
	party_panel.add_theme_stylebox_override("panel", _panel_style())
	enemies_panel.add_theme_stylebox_override("panel", _panel_style())


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.2, 0.92)
	style.border_color = Color(0.35, 0.35, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style


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

func _update_party_panel() -> void:
	_clear_children(party_list)
	var heroes := get_tree().get_nodes_in_group("heroes")
	for node in heroes:
		var hero := node as Hero
		if not hero:
			continue
		party_list.add_child(_make_hero_block(hero))


func _make_hero_block(hero: Hero) -> Control:
	var role_name: String = _hero_role_name(hero)
	var color: Color = _hero_role_color(hero)
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	var header := _make_label("%s" % role_name, 15)
	header.add_theme_color_override("font_color", color)
	block.add_child(header)
	block.add_child(_make_label("  HP: %d / %d" % [ceili(hero.hp), int(hero.max_hp)], 13))
	block.add_child(_make_label("  Atk: %.0f  Range: %.0f" % [hero.attack_power, hero.attack_range], 12))
	if hero.role and hero.role.armor > 0:
		block.add_child(_make_label("  Armor: %.0f" % hero.role.armor, 12))
	return block


func _update_enemies_panel() -> void:
	_clear_children(enemies_list)
	var enemies := get_tree().get_nodes_in_group("enemies")
	for node in enemies:
		var enemy := node as Enemy
		if not enemy:
			continue
		enemies_list.add_child(_make_enemy_block(enemy))
	if enemies_list.get_child_count() == 0:
		enemies_list.add_child(_make_label("(none)", 13))


func _make_enemy_block(enemy: Enemy) -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)
	var header := _make_label("%s" % enemy.name, 14)
	header.add_theme_color_override("font_color", Color(0.95, 0.5, 0.45))
	block.add_child(header)
	block.add_child(_make_label("  HP: %d / %d" % [ceili(enemy.hp), int(enemy.max_hp)], 12))
	block.add_child(_make_label("  Atk: %.0f  Range: %.0f" % [enemy.attack_damage, enemy.attack_range], 12))
	block.add_child(_make_label("  Aggro: %.0f  Spd: %.0f" % [enemy.aggro_range, enemy.move_speed], 12))
	return block


func _clear_children(parent: Control) -> void:
	for c in parent.get_children():
		c.queue_free()


func _make_label(text: String, size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	return lbl


func _hero_role_name(hero: Hero) -> String:
	if not hero.role:
		return "Hero"
	return hero.role.display_name


func _hero_role_color(hero: Hero) -> Color:
	if not hero.role:
		return Color(0.6, 0.7, 1.0)
	match hero.role.role_type:
		HeroRole.RoleType.TANK:
			return Color(0.85, 0.65, 0.35)
		HeroRole.RoleType.DPS:
			return Color(1.0, 0.4, 0.35)
		HeroRole.RoleType.HEALER:
			return Color(0.4, 0.75, 1.0)
	return Color(0.8, 0.8, 0.9)


func _update_death_counts() -> void:
	var fire_deaths: int = UnlockManager.get_death_count("fire")
	var unlocked: bool = UnlockManager.is_unlocked("avoid_fire")
	if unlocked:
		death_label.text = "  |  Fire deaths: %d  [AVOID FIRE unlocked]" % fire_deaths
	else:
		death_label.text = "  |  Fire deaths: %d / %d to unlock" % [fire_deaths, 3]


func _show_notification(text: String, color: Color, duration: float) -> void:
	notification_label.text = text
	notification_label.add_theme_color_override("font_color", color)
	_notification_timer = duration


func _tick_notification(real_delta: float) -> void:
	if _notification_timer > 0.0:
		_notification_timer -= real_delta
		if _notification_timer <= 0.0:
			notification_label.text = ""
