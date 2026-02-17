class_name HeroBrain
extends Node
## Builds and ticks a role-specific behavior tree each physics frame to drive a Hero.
## Tank: stick to melee until all enemies dead. DPS: maintain range, fire projectiles.
## Healer: heal lowest ally first, ranged attack when no healing needed.

var hero: Hero
var tree: BTNode
var unit_state: UnitState
var _last_velocity: Vector2 = Vector2.ZERO
var _locked_target: Node2D = null
var _target_lock_timer: float = 0.0
var _ranged_holding_tank_lead: bool = false  ## Hysteresis: avoid DPS flip-flop at tank-lead boundary
var _hazard_reaction_timer: float = 0.0  ## Countdown before hero "reacts" to hazard (progression: lower delay = smarter)
var _telegraph_was_active: bool = false  ## Used to refresh path when telegraph ends
var _run_completed: bool = false  ## When true, hero stays idle (no movement) after run success

const TARGET_LOCK_DURATION: float = 0.3
const HAZARD_AVOIDANCE_RADIUS: float = 140.0
const HAZARD_AVOIDANCE_STRENGTH: float = 3.0
const HEAL_HP_THRESHOLD: float = 0.80
const RANGE_TOLERANCE: float = 15.0
const SEPARATION_RADIUS: float = 28.0
const SEPARATION_STRENGTH: float = 1.2
const MELEE_DANGER_RADIUS: float = 50.0
const FLEE_EXIT_RADIUS: float = 58.0  ## Stop fleeing when nearest enemy beyond this (hysteresis)
const TANK_LEAD_HOLD_MARGIN: float = 35.0   ## DPS holds when this far ahead of tank
const TANK_LEAD_RESUME_MARGIN: float = 10.0  ## DPS resumes when at least this far behind tank (hysteresis)
const VELOCITY_SMOOTH: float = 0.25  ## Lerp toward desired direction to reduce jitter
const DIRECTION_DEAD_ZONE_RAD: float = 0.15  ## ~8.5°; ignore tiny direction changes to avoid left/right twitch
const TELEGRAPH_SAFETY_MARGIN: float = 45.0  ## Move this far past the telegraph edge before resuming; then find new path


func _ready() -> void:
	hero = get_parent() as Hero
	assert(hero != null, "HeroBrain must be a child of a Hero node")
	unit_state = UnitState.new()
	_build_tree()
	EventBus.run_ended.connect(_on_run_ended)


func _build_tree() -> void:
	var root := BTSelector.new()

	# Branch 1 (all roles): avoid hazards when unlocked (includes telegraphed boss fire)
	var avoid_seq := BTSequence.new()
	avoid_seq.add_child_node(BTCondition.new(_has_avoid_fire))
	avoid_seq.add_child_node(BTCondition.new(_is_near_hazard))
	avoid_seq.add_child_node(BTCondition.new(_has_reacted_to_hazard))
	avoid_seq.add_child_node(BTAction.new(_move_with_avoidance))
	root.add_child_node(avoid_seq)

	match hero.get_role_type():
		HeroRole.RoleType.TANK:
			_build_tank_branches(root)
		HeroRole.RoleType.DPS:
			_build_dps_branches(root)
		HeroRole.RoleType.HEALER:
			_build_healer_branches(root)

	tree = root


func _on_run_ended(success: bool) -> void:
	if success:
		_run_completed = true


func _build_tank_branches(root: BTSelector) -> void:
	# Tank priority: fight any alive enemy in melee, never leave combat
	var combat_seq := BTSequence.new()
	combat_seq.add_child_node(BTCondition.new(_has_any_alive_enemy))
	combat_seq.add_child_node(BTAction.new(_tank_combat_tick))
	root.add_child_node(combat_seq)
	# Only move to goal when no enemies remain
	root.add_child_node(BTAction.new(_move_to_goal))


func _build_dps_branches(root: BTSelector) -> void:
	# DPS: flee if any enemy in melee range, then combat
	var flee_seq := BTSequence.new()
	flee_seq.add_child_node(BTCondition.new(_is_any_enemy_in_melee_range))
	flee_seq.add_child_node(BTAction.new(_flee_from_melee_tick))
	root.add_child_node(flee_seq)
	var combat_seq := BTSequence.new()
	combat_seq.add_child_node(BTCondition.new(_has_any_alive_enemy))
	combat_seq.add_child_node(BTAction.new(_ranged_combat_tick))
	root.add_child_node(combat_seq)
	root.add_child_node(BTAction.new(_move_to_goal))


func _build_healer_branches(root: BTSelector) -> void:
	# Healer priority 1: heal allies
	var heal_seq := BTSequence.new()
	heal_seq.add_child_node(BTCondition.new(_ally_needs_heal))
	heal_seq.add_child_node(BTAction.new(_heal_tick))
	root.add_child_node(heal_seq)
	# Healer priority 2: flee if any enemy in melee range
	var flee_seq := BTSequence.new()
	flee_seq.add_child_node(BTCondition.new(_is_any_enemy_in_melee_range))
	flee_seq.add_child_node(BTAction.new(_flee_from_melee_tick))
	root.add_child_node(flee_seq)
	# Healer priority 3: ranged attack
	var combat_seq := BTSequence.new()
	combat_seq.add_child_node(BTCondition.new(_has_any_alive_enemy))
	combat_seq.add_child_node(BTAction.new(_ranged_combat_tick))
	root.add_child_node(combat_seq)
	root.add_child_node(BTAction.new(_move_to_goal))


func _physics_process(delta: float) -> void:
	if not hero.is_alive:
		hero.velocity = Vector2.ZERO
		unit_state.set_state(UnitState.State.IDLE)
		return
	if _run_completed:
		hero.velocity = Vector2.ZERO
		unit_state.set_state(UnitState.State.IDLE)
		return

	_target_lock_timer -= delta
	if _target_lock_timer <= 0.0 or not _is_valid_lock_target():
		_locked_target = null
	if UnlockManager.is_unlocked("avoid_fire"):
		if _is_near_hazard():
			if _is_inside_telegraph_fire_zone():
				_hazard_reaction_timer = 0.0  # React immediately when already in the damage zone
			elif _hazard_reaction_timer > 0.0:
				_hazard_reaction_timer -= delta
			else:
				_hazard_reaction_timer = hero.get_hazard_reaction_delay()
		else:
			_hazard_reaction_timer = 0.0
	var had_telegraph: bool = _get_telegraph_fire_zones().size() > 0
	if _telegraph_was_active and not had_telegraph:
		_refresh_nav_target()
	_telegraph_was_active = had_telegraph
	var blackboard: Dictionary = {"delta": delta}
	tree.tick(blackboard)
	var desired := _apply_separation(hero.velocity)
	desired = _apply_direction_dead_zone(desired)
	hero.velocity = _last_velocity.lerp(desired, VELOCITY_SMOOTH)
	_last_velocity = hero.velocity
	hero.move_and_slide()


# -- Conditions ---------------------------------------------------------------

func _has_avoid_fire() -> bool:
	return UnlockManager.is_unlocked("avoid_fire")


func _has_reacted_to_hazard() -> bool:
	return _hazard_reaction_timer <= 0.0


func _is_inside_telegraph_fire_zone() -> bool:
	for zone in _get_telegraph_fire_zones():
		var pos: Vector2 = zone.get("position", Vector2.ZERO)
		var radius: float = zone.get("radius", 50.0)
		var dist := hero.global_position.distance_to(pos)
		if dist < radius:
			return true
	return false


func _is_near_hazard() -> bool:
	if hero.is_in_hazard():
		return true
	for hazard in _get_known_hazards():
		var hazard_pos: Vector2 = (hazard as Node2D).global_position
		var dist := hero.global_position.distance_to(hazard_pos)
		if dist < HAZARD_AVOIDANCE_RADIUS:
			return true
	for zone in _get_telegraph_fire_zones():
		var pos: Vector2 = zone.get("position", Vector2.ZERO)
		var radius: float = zone.get("radius", 50.0)
		var dist := hero.global_position.distance_to(pos)
		if dist < radius + HAZARD_AVOIDANCE_RADIUS:
			return true
	return false


func _is_valid_lock_target() -> bool:
	if not _locked_target or not is_instance_valid(_locked_target):
		return false
	if _locked_target.get("is_alive") != true:
		return false
	if hero.global_position.distance_to(_locked_target.global_position) > 400.0:
		return false
	return true


func _has_any_alive_enemy() -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		if node.get("is_alive") == true:
			return true
	return false


func _is_any_enemy_in_melee_range() -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		if node.get("is_alive") != true:
			continue
		var e := node as Node2D
		if e and hero.global_position.distance_to(e.global_position) < MELEE_DANGER_RADIUS:
			return true
	return false


func _ally_needs_heal() -> bool:
	if not hero.can_heal():
		return false
	var target := _get_lowest_hp_ally()
	return target != null


# -- Tank combat --------------------------------------------------------------

func _tank_combat_tick(_blackboard: Dictionary) -> BTNode.Status:
	var target := _get_nearest_enemy()
	if not target:
		unit_state.set_state(UnitState.State.IDLE)
		return BTNode.Status.FAILURE
	_locked_target = target
	_target_lock_timer = TARGET_LOCK_DURATION
	var dist := hero.global_position.distance_to(target.global_position)
	if dist <= hero.attack_range:
		if hero.can_attack():
			unit_state.set_state(UnitState.State.ATTACKING)
			hero.velocity = Vector2.ZERO
			hero.perform_attack(target)
		else:
			hero.velocity = Vector2.ZERO
		return BTNode.Status.RUNNING
	# Close distance to melee range
	unit_state.set_state(UnitState.State.MOVING)
	hero.velocity = (target.global_position - hero.global_position).normalized() * hero.move_speed
	return BTNode.Status.RUNNING


# -- Ranged combat (DPS and Healer attack) ------------------------------------

func _ranged_combat_tick(_blackboard: Dictionary) -> BTNode.Status:
	var target := _get_nearest_enemy()
	if not target:
		unit_state.set_state(UnitState.State.IDLE)
		return BTNode.Status.FAILURE
	_locked_target = target
	_target_lock_timer = TARGET_LOCK_DURATION
	var dist := hero.global_position.distance_to(target.global_position)
	var preferred := hero.get_preferred_range_distance()
	if dist <= hero.attack_range:
		# In attack range -- try to attack
		if hero.can_attack():
			unit_state.set_state(UnitState.State.ATTACKING)
			hero.velocity = Vector2.ZERO
			_spawn_attack_projectile(target)
			return BTNode.Status.RUNNING
		# Waiting for cooldown -- maintain preferred distance
		if dist < preferred - RANGE_TOLERANCE:
			# Too close, back away
			unit_state.set_state(UnitState.State.MOVING)
			hero.velocity = (hero.global_position - target.global_position).normalized() * hero.move_speed * 0.6
		else:
			hero.velocity = Vector2.ZERO
		return BTNode.Status.RUNNING
	# Out of range: only move closer if tank is leading (tank closer to target than we are).
	# Hysteresis: hold when ahead, resume only when clearly behind tank to avoid twitching.
	var enemy_pos: Vector2 = target.global_position
	var tank := _get_tank()
	if tank:
		var my_dist := hero.global_position.distance_to(enemy_pos)
		var tank_dist := tank.global_position.distance_to(enemy_pos)
		if tank_dist > my_dist + TANK_LEAD_HOLD_MARGIN:
			_ranged_holding_tank_lead = true
		elif my_dist >= tank_dist + TANK_LEAD_RESUME_MARGIN:
			_ranged_holding_tank_lead = false
		if _ranged_holding_tank_lead:
			unit_state.set_state(UnitState.State.IDLE)
			hero.velocity = Vector2.ZERO
			return BTNode.Status.RUNNING
	unit_state.set_state(UnitState.State.MOVING)
	hero.velocity = (target.global_position - hero.global_position).normalized() * hero.move_speed
	return BTNode.Status.RUNNING


func _flee_from_melee_tick(_blackboard: Dictionary) -> BTNode.Status:
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for node in get_tree().get_nodes_in_group("enemies"):
		if node.get("is_alive") != true:
			continue
		var e := node as Node2D
		if not e:
			continue
		var d := hero.global_position.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	if not nearest:
		return BTNode.Status.FAILURE
	# Hysteresis: stop fleeing once we're safely out of range (avoids flee/combat flip every frame)
	if nearest_dist > FLEE_EXIT_RADIUS:
		return BTNode.Status.FAILURE
	unit_state.set_state(UnitState.State.FLEEING)
	hero.velocity = (hero.global_position - nearest.global_position).normalized() * hero.move_speed * 0.8
	return BTNode.Status.RUNNING


# -- Heal tick ----------------------------------------------------------------

func _heal_tick(_blackboard: Dictionary) -> BTNode.Status:
	var target := _get_lowest_hp_ally()
	if not target:
		unit_state.set_state(UnitState.State.IDLE)
		return BTNode.Status.FAILURE
	var dist := hero.global_position.distance_to(target.global_position)
	if dist <= hero.heal_range:
		if hero.can_heal():
			unit_state.set_state(UnitState.State.USING_ABILITY)
			hero.velocity = Vector2.ZERO
			_spawn_heal_projectile(target)
			return BTNode.Status.RUNNING
		hero.velocity = Vector2.ZERO
		return BTNode.Status.RUNNING
	# Move closer to ally
	unit_state.set_state(UnitState.State.MOVING)
	hero.velocity = (target.global_position - hero.global_position).normalized() * hero.move_speed
	return BTNode.Status.RUNNING


# -- Direction dead zone (reduce twitch) ---------------------------------------

func _apply_direction_dead_zone(desired: Vector2) -> Vector2:
	var len_desired := desired.length()
	var len_last := _last_velocity.length()
	if len_desired < 0.01 or len_last < 0.01:
		return desired
	var dir_desired := desired.normalized()
	var dir_last := _last_velocity.normalized()
	var dot := dir_desired.dot(dir_last)
	if dot >= 0.9999:
		return desired
	var angle := acos(clampf(dot, -1.0, 1.0))
	if angle < DIRECTION_DEAD_ZONE_RAD:
		return dir_last * len_desired
	return desired


# -- Separation ----------------------------------------------------------------

func _apply_separation(base_velocity: Vector2) -> Vector2:
	var len := base_velocity.length()
	if len < 0.01:
		return base_velocity
	# Only separate from other heroes so we path around allies; don't push away from enemies (caused jitter in boss room)
	var separation := Vector2.ZERO
	for node in get_tree().get_nodes_in_group("heroes"):
		if node == hero:
			continue
		var other: Node2D = node as Node2D
		if not other:
			continue
		var to_other: Vector2 = other.global_position - hero.global_position
		var dist := to_other.length()
		if dist > 0.0 and dist < SEPARATION_RADIUS:
			var strength := 1.0 - (dist / SEPARATION_RADIUS)
			separation += -to_other.normalized() * strength
	if separation.length_squared() < 0.01:
		return base_velocity
	var dir := (base_velocity.normalized() + separation.normalized() * SEPARATION_STRENGTH).normalized()
	return dir * len


# -- Avoidance ----------------------------------------------------------------

func _move_with_avoidance(_blackboard: Dictionary) -> BTNode.Status:
	# If inside or barely outside a telegraphed fire zone, move out past the edge (safety margin) then find new path
	for zone in _get_telegraph_fire_zones():
		var pos: Vector2 = zone.get("position", Vector2.ZERO)
		var radius: float = zone.get("radius", 50.0)
		var to_zone: Vector2 = pos - hero.global_position
		var dist := to_zone.length()
		if dist < radius + TELEGRAPH_SAFETY_MARGIN and dist > 0.0:
			var away: Vector2 = -to_zone.normalized()
			unit_state.set_state(UnitState.State.MOVING)
			hero.velocity = away * hero.move_speed
			return BTNode.Status.RUNNING

	var to_goal := _get_direction_to_goal()
	if to_goal.length() < 8.0:
		hero.velocity = Vector2.ZERO
		return BTNode.Status.SUCCESS

	var goal_dir := to_goal.normalized()
	var avoidance := Vector2.ZERO

	for hazard in _get_known_hazards():
		var hazard_node: Node2D = hazard as Node2D
		var to_hazard: Vector2 = hazard_node.global_position - hero.global_position
		var dist := to_hazard.length()
		if dist < HAZARD_AVOIDANCE_RADIUS and dist > 0.0:
			var strength := 1.0 - (dist / HAZARD_AVOIDANCE_RADIUS)
			var away := -to_hazard.normalized()
			var perp := Vector2(-away.y, away.x)
			if perp.dot(goal_dir) < 0.0:
				perp = -perp
			avoidance += (away * 0.3 + perp * 0.7).normalized() * strength

	for zone in _get_telegraph_fire_zones():
		var pos: Vector2 = zone.get("position", Vector2.ZERO)
		var radius: float = zone.get("radius", 50.0)
		var to_zone: Vector2 = pos - hero.global_position
		var dist := to_zone.length()
		var avoid_radius: float = radius + HAZARD_AVOIDANCE_RADIUS
		if dist < avoid_radius and dist > 0.0:
			var strength := 1.0 - (dist / avoid_radius)
			var away := -to_zone.normalized()
			var perp := Vector2(-away.y, away.x)
			if perp.dot(goal_dir) < 0.0:
				perp = -perp
			avoidance += (away * 0.3 + perp * 0.7).normalized() * strength

	unit_state.set_state(UnitState.State.MOVING)
	var final_dir := (goal_dir + avoidance * HAZARD_AVOIDANCE_STRENGTH).normalized()
	hero.velocity = final_dir * hero.move_speed
	return BTNode.Status.RUNNING


func _move_to_goal(_blackboard: Dictionary) -> BTNode.Status:
	var to_goal := _get_direction_to_goal()
	if to_goal.length() < 8.0:
		hero.velocity = Vector2.ZERO
		unit_state.set_state(UnitState.State.IDLE)
		return BTNode.Status.SUCCESS

	unit_state.set_state(UnitState.State.MOVING)
	hero.velocity = to_goal.normalized() * hero.move_speed
	return BTNode.Status.RUNNING


# -- Projectile spawning (placeholder: instant until projectile.gd exists) ----

func _spawn_attack_projectile(target: Node2D) -> void:
	hero._attack_timer = hero.attack_cooldown
	var proj := Projectile.new()
	proj.setup(hero.global_position, target, hero.attack_power, "hero", hero._get_body_color())
	hero.get_parent().add_child(proj)


func _spawn_heal_projectile(target: Hero) -> void:
	hero._heal_timer = hero.heal_cooldown
	var proj := Projectile.new()
	proj.setup_heal(hero.global_position, target, hero.heal_power, Color(0.3, 1.0, 0.4))
	hero.get_parent().add_child(proj)


# -- Navigation ----------------------------------------------------------------

func _get_direction_to_goal() -> Vector2:
	var nav: NavigationAgent2D = hero.get_nav_agent()
	if not nav:
		return hero.goal_position - hero.global_position
	nav.set_target_position(hero.goal_position)
	if nav.is_navigation_finished():
		return hero.goal_position - hero.global_position
	var next_pos: Vector2 = nav.get_next_path_position()
	return next_pos - hero.global_position


func _refresh_nav_target() -> void:
	var nav: NavigationAgent2D = hero.get_nav_agent()
	if nav:
		nav.set_target_position(hero.goal_position)


# -- Helpers ------------------------------------------------------------------

func _get_nearest_enemy() -> Node2D:
	if _is_valid_lock_target():
		return _locked_target
	var enemies := get_tree().get_nodes_in_group("enemies")
	var best: Node2D = null
	var best_dist: float = 1e6
	for node in enemies:
		var e := node as Node2D
		if not e or not e.has_method("take_damage"):
			continue
		if e.get("is_alive") == false:
			continue
		var d := hero.global_position.distance_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best


func _get_lowest_hp_ally() -> Hero:
	var heroes := get_tree().get_nodes_in_group("heroes")
	var best: Hero = null
	var lowest_ratio: float = HEAL_HP_THRESHOLD
	for node in heroes:
		var h := node as Hero
		if not h or not h.is_alive:
			continue
		var ratio := h.hp / h.max_hp
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			best = h
	return best


func _get_tank() -> Hero:
	for node in get_tree().get_nodes_in_group("heroes"):
		var h := node as Hero
		if h and h.is_alive and h.get_role_type() == HeroRole.RoleType.TANK:
			return h
	return null


func _get_known_hazards() -> Array:
	return get_tree().get_nodes_in_group("fire_hazards")


func _get_telegraph_fire_zones() -> Array:
	var registry: Node = get_node_or_null("/root/HazardTelegraphRegistry")
	if not registry or not registry.has_method("get_current_fire_telegraph"):
		return []
	var t: Dictionary = registry.get_current_fire_telegraph()
	if t.is_empty():
		return []
	return [t]
