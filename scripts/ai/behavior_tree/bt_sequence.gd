class_name BTSequence
extends BTNode
## Runs each child in order. Returns the first non-SUCCESS result.

var children: Array[BTNode] = []


func tick(blackboard: Dictionary) -> Status:
	for child in children:
		var result := child.tick(blackboard)
		if result != Status.SUCCESS:
			return result
	return Status.SUCCESS


func add_child_node(node: BTNode) -> BTSequence:
	children.append(node)
	return self
