class_name HeroBrain
extends Node
## Builds and ticks a behavior tree each physics frame to drive a Hero.

var hero: Hero
var tree: BTNode

const HAZARD_AVOIDANCE_RADIUS: float = 140.0
const HAZARD_AVOIDANCE_STRENGTH: float = 3.0


func _ready() -> void:
	hero = get_parent() as Hero
	assert(hero != null, "HeroBrain must be a child of a Hero node")
	_build_tree()


func _build_tree() -> void:
	var root := BTSelector.new()

	# Branch 1: avoid hazards (only when avoid_fire is unlocked AND near hazard)
	var avoid_seq := BTSequence.new()
	avoid_seq.add_child_node(BTCondition.new(_has_avoid_fire))
	avoid_seq.add_child_node(BTCondition.new(_is_near_hazard))
	avoid_seq.add_child_node(BTAction.new(_move_with_avoidance))
	root.add_child_node(avoid_seq)

	# Branch 2: move directly to goal
	root.add_child_node(BTAction.new(_move_to_goal))

	tree = root


func _physics_process(delta: float) -> void:
	if not hero.is_alive:
		hero.velocity = Vector2.ZERO
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

	var final_dir := (goal_dir + avoidance * HAZARD_AVOIDANCE_STRENGTH).normalized()
	hero.velocity = final_dir * hero.move_speed
	return BTNode.Status.RUNNING


func _move_to_goal(_blackboard: Dictionary) -> BTNode.Status:
	var to_goal := hero.goal_position - hero.global_position
	if to_goal.length() < 8.0:
		hero.velocity = Vector2.ZERO
		return BTNode.Status.SUCCESS

	hero.velocity = to_goal.normalized() * hero.move_speed
	return BTNode.Status.RUNNING


# -- Helpers ------------------------------------------------------------------

func _get_known_hazards() -> Array:
	return get_tree().get_nodes_in_group("fire_hazards")
