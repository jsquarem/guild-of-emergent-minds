class_name HeroBrain
extends Node
## Builds and ticks a behavior tree each physics frame to drive a Hero.
## State machine (Idle, Moving, Attacking, UsingAbility, Fleeing) wraps BT for debugging.

var hero: Hero
var tree: BTNode
var unit_state: UnitState

const HAZARD_AVOIDANCE_RADIUS: float = 140.0
const HAZARD_AVOIDANCE_STRENGTH: float = 3.0


func _ready() -> void:
	hero = get_parent() as Hero
	assert(hero != null, "HeroBrain must be a child of a Hero node")
	unit_state = UnitState.new()
	_build_tree()


func _build_tree() -> void:
	var root := BTSelector.new()

	# Branch 1: avoid hazards (only when avoid_fire is unlocked AND near hazard)
	var avoid_seq := BTSequence.new()
	avoid_seq.add_child_node(BTCondition.new(_has_avoid_fire))
	avoid_seq.add_child_node(BTCondition.new(_is_near_hazard))
	avoid_seq.add_child_node(BTAction.new(_move_with_avoidance))
	root.add_child_node(avoid_seq)

	# Branch 2: combat — attack enemy in range, else move toward nearest enemy
	var combat_seq := BTSequence.new()
	combat_seq.add_child_node(BTCondition.new(_has_nearby_enemy))
	combat_seq.add_child_node(BTAction.new(_combat_tick))
	root.add_child_node(combat_seq)

	# Branch 3: move directly to goal
	root.add_child_node(BTAction.new(_move_to_goal))

	tree = root


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


func _has_nearby_enemy() -> bool:
	return _get_nearest_enemy() != null


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


func _combat_tick(_blackboard: Dictionary) -> BTNode.Status:
	var target := _get_nearest_enemy()
	if not target:
		unit_state.set_state(UnitState.State.IDLE)
		return BTNode.Status.FAILURE
	var dist := hero.global_position.distance_to(target.global_position)
	if dist <= hero.attack_range and hero.can_attack():
		unit_state.set_state(UnitState.State.ATTACKING)
		hero.velocity = Vector2.ZERO
		hero.perform_attack(target)
		return BTNode.Status.RUNNING
	unit_state.set_state(UnitState.State.MOVING)
	hero.velocity = (target.global_position - hero.global_position).normalized() * hero.move_speed
	return BTNode.Status.RUNNING


# -- Actions ------------------------------------------------------------------

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
			# Perpendicular component so hero steers *around* the hazard
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


# -- Helpers ------------------------------------------------------------------

func _get_known_hazards() -> Array:
	return get_tree().get_nodes_in_group("fire_hazards")
