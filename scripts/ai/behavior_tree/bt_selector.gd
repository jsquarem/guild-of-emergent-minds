class_name BTSelector
extends BTNode
## Tries each child in order. Returns the first non-FAILURE result.

var children: Array[BTNode] = []


func tick(blackboard: Dictionary) -> Status:
	for child in children:
		var result := child.tick(blackboard)
		if result != Status.FAILURE:
			return result
	return Status.FAILURE


func add_child_node(node: BTNode) -> BTSelector:
	children.append(node)
	return self
