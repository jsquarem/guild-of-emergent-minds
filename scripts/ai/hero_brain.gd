class_name HeroBrain
extends Node
## Builds and ticks a role-specific behavior tree each physics frame to drive a Hero.
## Tank: stick to melee until all enemies dead. DPS: maintain range, fire projectiles.
## Healer: heal lowest ally first, ranged attack when no healing needed.

var hero: Hero
var tree: BTNode
var unit_state: UnitState

const HAZARD_AVOIDANCE_RADIUS: float = 140.0
const HAZARD_AVOIDANCE_STRENGTH: float = 3.0
const HEAL_HP_THRESHOLD: float = 0.80
const RANGE_TOLERANCE: float = 15.0


func _ready() -> void:
	hero = get_parent() as Hero
	assert(hero != null, "HeroBrain must be a child of a Hero node")
	unit_state = UnitState.new()
	_build_tree()


func _build_tree() -> void:
	var root := BTSelector.new()

	# Branch 1 (all roles): avoid hazards when unlocked
	var avoid_seq := BTSequence.new()
	avoid_seq.add_child_node(BTCondition.new(_has_avoid_fire))
	avoid_seq.add_child_node(BTCondition.new(_is_near_hazard))
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


func _build_tank_branches(root: BTSelector) -> void:
	# Tank priority: fight any alive enemy in melee, never leave combat
	var combat_seq := BTSequence.new()
	combat_seq.add_child_node(BTCondition.new(_has_any_alive_enemy))
	combat_seq.add_child_node(BTAction.new(_tank_combat_tick))
	root.add_child_node(combat_seq)
	# Only move to goal when no enemies remain
	root.add_child_node(BTAction.new(_move_to_goal))


func _build_dps_branches(root: BTSelector) -> void:
	# DPS priority: maintain range, fire projectiles
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
	# Healer priority 2: ranged attack
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

	var blackboard: Dictionary = {"delta": delta}
	tree.tick(blackboard)
	hero.move_and_slide()


# -- Conditions ---------------------------------------------------------------

func _has_avoid_fire() -> bool:
	return UnlockManager.is_unlocked("avoid_fire")


func _is_near_hazard() -> bool:
	if hero.is_in_hazard():
		return true
	for hazard in _get_known_hazards():
		var hazard_pos: Vector2 = (hazard as Node2D).global_position
		var dist := hero.global_position.distance_to(hazard_pos)
		if dist < HAZARD_AVOIDANCE_RADIUS:
			return true
	return false


func _has_any_alive_enemy() -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		if node.get("is_alive") == true:
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
	# Out of range, move closer
	unit_state.set_state(UnitState.State.MOVING)
	hero.velocity = (target.global_position - hero.global_position).normalized() * hero.move_speed
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


# -- Avoidance ----------------------------------------------------------------

func _move_with_avoidance(_blackboard: Dictionary) -> BTNode.Status:
	var to_goal := hero.goal_position - hero.global_position
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

	unit_state.set_state(UnitState.State.MOVING)
	var final_dir := (goal_dir + avoidance * HAZARD_AVOIDANCE_STRENGTH).normalized()
	hero.velocity = final_dir * hero.move_speed
	return BTNode.Status.RUNNING


func _move_to_goal(_blackboard: Dictionary) -> BTNode.Status:
	var to_goal := hero.goal_position - hero.global_position
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


# -- Helpers ------------------------------------------------------------------

func _get_nearest_enemy() -> Node2D:
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


func _get_known_hazards() -> Array:
	return get_tree().get_nodes_in_group("fire_hazards")
