class_name Hero
extends CharacterBody2D
## A single guild hero. Moves via behavior tree, tracks HP and hazard overlaps.
## If role is set, stats come from the role; otherwise uses @export defaults.

signal damaged(amount: float, source_type: String)
signal died(cause: String)
signal healed(amount: float)

@export var role: HeroRole
@export var max_hp: float = 100.0
@export var move_speed: float = 80.0

var hp: float
var is_alive: bool = true
var active_hazards: Array[Area2D] = []
var goal_position: Vector2 = Vector2.ZERO
var attack_range: float = 40.0
var attack_cooldown: float = 1.0
var attack_power: float = 10.0
var _attack_timer: float = 0.0

var heal_power: float = 0.0
var heal_range: float = 0.0
var heal_cooldown: float = 2.0
var _heal_timer: float = 0.0

## Smoothed facing for display; lerped toward velocity so turning doesn't look twitchy.
var _display_facing: Vector2 = Vector2.RIGHT
const FACING_SMOOTH_SPEED: float = 6.0  ## Lerp per second toward velocity direction
const FACING_MIN_SPEED: float = 8.0  ## Don't update facing when moving slower than this

## Tank sprite: AnimatedSprite2D when role is TANK and a spritesheet path is set (idle, walk, attack, get_hit).
var _tank_sprite: AnimatedSprite2D = null
var _one_shot_playing: bool = false  ## True while attack or get_hit is playing

## If non-empty and role is TANK, load this spritesheet and use it (8 cols × 4 rows: idle, walk, attack, get_hit). Leave empty for circle placeholder.
@export var tank_sprite_path: String = ""
const TANK_ANIM_COLS: int = 8
const TANK_ANIM_ROWS: int = 4  ## idle, walk, attack, get_hit (row 0..3)


func _ready() -> void:
	if role:
		max_hp = role.max_hp
		move_speed = role.move_speed
		attack_range = role.attack_range
		attack_cooldown = role.attack_cooldown
		attack_power = role.attack_power
		heal_power = role.heal_power
		heal_range = role.heal_range
		heal_cooldown = role.heal_cooldown
	hp = max_hp
	add_to_group("heroes")
	if role and role.role_type == HeroRole.RoleType.TANK and not tank_sprite_path.is_empty():
		_setup_tank_sprite()


func get_role_type() -> HeroRole.RoleType:
	if role:
		return role.role_type
	return HeroRole.RoleType.DPS


func get_preferred_range_distance() -> float:
	if role:
		return role.get_preferred_distance()
	return 50.0


func get_hazard_reaction_delay() -> float:
	var base_delay: float = 0.35
	if role:
		base_delay = role.hazard_reaction_delay
	var data: Dictionary = SaveManager.load_data()
	var level: int = data.get("training_level", 0)
	# Each level reduces reaction delay by 10%; minimum 0.1s
	var multiplier: float = 1.0 - level * 0.1
	multiplier = maxf(multiplier, 0.25)
	return base_delay * multiplier


func get_nav_agent() -> NavigationAgent2D:
	return get_node_or_null("NavigationAgent2D") as NavigationAgent2D


func take_damage(amount: float, source_type: String = "unknown") -> void:
	if not is_alive:
		return
	var reduced := amount
	if role:
		reduced = maxf(0.0, amount - role.armor)
	hp -= reduced
	damaged.emit(reduced, source_type)
	EventBus.hero_damaged.emit(self, reduced, source_type)
	_spawn_floating_number(reduced, false)
	if _tank_sprite and hp > 0.0:
		_one_shot_playing = true
		_tank_sprite.play("get_hit")
	if hp <= 0.0:
		hp = 0.0
		die(source_type)


func die(cause: String = "unknown") -> void:
	if not is_alive:
		return
	is_alive = false
	died.emit(cause)
	EventBus.hero_died.emit(self, cause)


func heal(amount: float) -> void:
	if not is_alive:
		return
	var actual := minf(amount, max_hp - hp)
	if actual <= 0.0:
		return
	hp += actual
	healed.emit(actual)
	_spawn_floating_number(actual, true)
	_spawn_heal_effect()


func can_attack() -> bool:
	return _attack_timer <= 0.0


func can_heal() -> bool:
	return _heal_timer <= 0.0 and heal_power > 0.0


func perform_heal(target: Hero) -> bool:
	if not can_heal() or not target or not target.is_alive:
		return false
	if target.hp >= target.max_hp:
		return false
	target.heal(heal_power)
	_heal_timer = heal_cooldown
	return true


func perform_attack(target: Node2D) -> bool:
	if not can_attack() or not target:
		return false
	if target.has_method("take_damage"):
		target.take_damage(attack_power, "hero")
		_attack_timer = attack_cooldown
		if _tank_sprite:
			_one_shot_playing = true
			_tank_sprite.play("attack")
		return true
	return false


func _process(delta: float) -> void:
	if is_alive:
		_attack_timer -= delta
		_heal_timer -= delta
		_update_display_facing(delta)
	if _tank_sprite:
		_update_tank_sprite()
	queue_redraw()


func _update_display_facing(delta: float) -> void:
	if velocity.length() >= FACING_MIN_SPEED:
		var target_dir: Vector2 = velocity.normalized()
		_display_facing = _display_facing.lerp(target_dir, delta * FACING_SMOOTH_SPEED).normalized()
		if _display_facing.length_squared() < 0.01:
			_display_facing = target_dir


func _setup_tank_sprite() -> void:
	var tex: Texture2D = load(tank_sprite_path) as Texture2D
	if not tex:
		push_error("Hero: failed to load tank sprite: %s" % tank_sprite_path)
		return
	var tex_size: Vector2 = tex.get_size()
	# Sheet: 8 columns; first 4 rows = idle, walk, attack, get_hit. Assume 5th row exists (die) so row height = height/5.
	var frame_w: int = int(tex_size.x / float(TANK_ANIM_COLS))
	var frame_h: int = int(tex_size.y / 5.0)
	if frame_w <= 0 or frame_h <= 0:
		push_error("Hero: tank sprite size too small: %s" % tex_size)
		return
	var frames := SpriteFrames.new()
	var anim_names: PackedStringArray = PackedStringArray(["idle", "walk", "attack", "get_hit"])
	for row in range(TANK_ANIM_ROWS):
		frames.add_animation(anim_names[row])
		# idle and walk loop; attack and get_hit are one-shots
		frames.set_animation_loop(anim_names[row], row <= 1)
		frames.set_animation_speed(anim_names[row], 8.0)
		for col in range(TANK_ANIM_COLS):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2i(col * frame_w, row * frame_h, frame_w, frame_h)
			frames.add_frame(anim_names[row], atlas, 1.0)
	var sprite := AnimatedSprite2D.new()
	sprite.name = "TankSprite"
	sprite.sprite_frames = frames
	sprite.animation = &"idle"
	sprite.position = Vector2(-frame_w / 2.0, -frame_h)  # Center horizontally, pivot at feet
	sprite.animation_finished.connect(_on_tank_sprite_animation_finished)
	add_child(sprite)
	_tank_sprite = sprite


func _on_tank_sprite_animation_finished() -> void:
	_one_shot_playing = false


func _update_tank_sprite() -> void:
	if not is_instance_valid(_tank_sprite):
		return
	# Flip based on facing (sprite faces right by default)
	var face_right: bool = _display_facing.x >= 0
	_tank_sprite.scale.x = 1.0 if face_right else -1.0
	if _one_shot_playing:
		return
	if velocity.length() >= FACING_MIN_SPEED:
		if _tank_sprite.animation != "walk":
			_tank_sprite.play("walk")
	else:
		if _tank_sprite.animation != "idle":
			_tank_sprite.play("idle")


func is_in_hazard(hazard_type: String = "") -> bool:
	if hazard_type.is_empty():
		return not active_hazards.is_empty()
	for hazard in active_hazards:
		if hazard.has_method("get_hazard_type") and hazard.get_hazard_type() == hazard_type:
			return true
	return false


func register_hazard(hazard: Area2D) -> void:
	if hazard not in active_hazards:
		active_hazards.append(hazard)


func unregister_hazard(hazard: Area2D) -> void:
	active_hazards.erase(hazard)


func _get_body_color() -> Color:
	if not is_alive:
		return Color(0.3, 0.3, 0.3, 0.5)
	if role:
		match role.role_type:
			HeroRole.RoleType.TANK:
				return Color(0.5, 0.35, 0.2)
			HeroRole.RoleType.DPS:
				return Color(0.9, 0.25, 0.2)
			HeroRole.RoleType.HEALER:
				return Color(0.3, 0.6, 0.9)
	return Color(0.2, 0.4, 0.9)


func _spawn_floating_number(amount: float, is_heal: bool) -> void:
	var fn: FloatingNumber
	if is_heal:
		fn = FloatingNumber.create_heal(amount, global_position)
	else:
		fn = FloatingNumber.create_damage(amount, global_position)
	var parent := get_parent()
	if parent:
		parent.add_child(fn)


func _spawn_heal_effect() -> void:
	var effect := HealEffect.new()
	add_child(effect)


func _draw() -> void:
	var bar_width: float = 20.0
	var bar_y: float = -14.0
	var hp_ratio := hp / max_hp
	# HP bar above head (always drawn)
	draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width, 3.0), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(-bar_width / 2.0, bar_y, bar_width * hp_ratio, 3.0), Color(0.1, 0.9, 0.2))
	if _tank_sprite:
		return
	if is_alive:
		draw_circle(Vector2.ZERO, 8.0, _get_body_color())
		var dir: Vector2 = _display_facing.normalized() if _display_facing.length_squared() > 0.01 else Vector2.RIGHT
		draw_line(Vector2.ZERO, dir * 12.0, Color.WHITE, 2.0)
	else:
		draw_circle(Vector2.ZERO, 8.0, _get_body_color())
