extends Node
## Tracks hero deaths per cause and unlocks AI behaviors after thresholds.

var unlocked_behaviors: Dictionary = {}
var death_counts: Dictionary = {}

const UNLOCK_THRESHOLDS: Dictionary = {
	"fire": {"behavior": "avoid_fire", "deaths_required": 3},
}


func _ready() -> void:
	EventBus.hero_died.connect(_on_hero_died)
	var data := SaveManager.load_data()
	_load_from_save(data)


func is_unlocked(behavior_id: String) -> bool:
	return unlocked_behaviors.has(behavior_id)


func get_death_count(cause: String) -> int:
	return death_counts.get(cause, 0)


func _on_hero_died(_hero: CharacterBody2D, cause: String) -> void:
	death_counts[cause] = death_counts.get(cause, 0) + 1
	_check_unlocks(cause)
	_persist()


func _check_unlocks(cause: String) -> void:
	if UNLOCK_THRESHOLDS.has(cause):
		var threshold: Dictionary = UNLOCK_THRESHOLDS[cause]
		var behavior_id: String = threshold["behavior"]
		var required: int = threshold["deaths_required"]
		if not is_unlocked(behavior_id) and get_death_count(cause) >= required:
			_unlock_behavior(behavior_id)


func _unlock_behavior(behavior_id: String) -> void:
	unlocked_behaviors[behavior_id] = true
	EventBus.behavior_unlocked.emit(behavior_id)
	print("[UnlockManager] Behavior unlocked: %s" % behavior_id)


func _persist() -> void:
	SaveManager.save_data({
		"unlock_data": {
			"unlocked_behaviors": unlocked_behaviors.duplicate(),
			"death_counts": death_counts.duplicate(),
		}
	})


func _load_from_save(data: Dictionary) -> void:
	var unlock_data: Dictionary = data.get("unlock_data", {})
	unlocked_behaviors = unlock_data.get("unlocked_behaviors", {})
	death_counts = unlock_data.get("death_counts", {})
