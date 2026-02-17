extends Node
## Holds the list of dungeons (path or graph). Used by Map for display and GameManager for completion rewards.
## Each dungeon can list required_predecessor_ids; a dungeon is open when all predecessors are in completed_dungeon_ids.

const DUNGEON_PATH: Array[Dictionary] = [
	{
		"id": "dungeon_1",
		"display_name": "First Gate",
		"difficulty": 1,
		"rewards": {"gold": 20, "reputation": 10},
		"required_predecessor_ids": [],  # First dungeon: no prereqs
	},
	# Add more with required_predecessor_ids: ["dungeon_1"] for linear, or multiple IDs for branches.
]


func get_dungeon_at_index(index: int) -> Dictionary:
	if index < 0 or index >= DUNGEON_PATH.size():
		return {}
	return DUNGEON_PATH[index]


func get_rewards_for_index(index: int) -> Dictionary:
	var d: Dictionary = get_dungeon_at_index(index)
	return d.get("rewards", {})


func get_path_size() -> int:
	return DUNGEON_PATH.size()


## Returns true if every required predecessor is in completed_ids.
func is_dungeon_open(dungeon: Dictionary, completed_ids: Array) -> bool:
	var prereqs: Array = dungeon.get("required_predecessor_ids", [])
	for pid in prereqs:
		if pid not in completed_ids:
			return false
	return true
