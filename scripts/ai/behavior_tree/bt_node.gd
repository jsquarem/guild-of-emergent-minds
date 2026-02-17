class_name BTNode
extends RefCounted
## Base class for all behavior tree nodes.

enum Status { SUCCESS, FAILURE, RUNNING }


func tick(_blackboard: Dictionary) -> Status:
	return Status.FAILURE
