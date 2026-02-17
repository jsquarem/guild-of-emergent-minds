class_name BTCondition
extends BTNode
## Leaf node that evaluates a callable. Returns SUCCESS if true, FAILURE if false.

var condition: Callable


func _init(callable: Callable) -> void:
	condition = callable


func tick(_blackboard: Dictionary) -> Status:
	if condition.call():
		return Status.SUCCESS
	return Status.FAILURE
