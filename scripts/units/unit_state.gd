class_name UnitState
extends RefCounted
## Unit state for debugging and future "reaction speed." Wraps behavior tree execution.

enum State { IDLE, MOVING, ATTACKING, USING_ABILITY, FLEEING }

var current: State = State.IDLE


func set_state(new_state: State) -> void:
	current = new_state


func is_idle() -> bool:
	return current == State.IDLE


func is_moving() -> bool:
	return current == State.MOVING


func is_attacking() -> bool:
	return current == State.ATTACKING


func is_using_ability() -> bool:
	return current == State.USING_ABILITY


func is_fleeing() -> bool:
	return current == State.FLEEING
