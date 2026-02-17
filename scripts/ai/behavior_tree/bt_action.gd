class_name BTAction
extends BTNode
## Leaf node that executes a callable and returns its Status result.

var action: Callable


func _init(callable: Callable) -> void:
	action = callable


func tick(blackboard: Dictionary) -> Status:
	return action.call(blackboard)
