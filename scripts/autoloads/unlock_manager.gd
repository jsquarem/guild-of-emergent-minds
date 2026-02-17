extends Node
## Tracks hero deaths and mechanic hits per cause; unlocks AI behaviors after thresholds.

var unlocked_behaviors: Dictionary = {}
var death_counts: Dictionary = {}
var mechanic_hit_counts: Dictionary = {}

const MECHANIC_CAUSES: Array[String] = ["fire", "line_attack", "target_swap"]

const UNLOCK_THRESHOLDS: Dictionary = {
	"fire": {"behavior": "avoid_fire", "deaths_required": 3, "hits_required": 6},
}


func _ready() -> void:
	EventBus.hero_died.connect(_on_hero_died)
	EventBus.hero_damaged.connect(_on_hero_damaged)
	EventBus.game_reset.connect(_on_game_reset)
	var data := SaveManager.load_data()
	_load_from_save(data)


func is_unlocked(behavior_id: String) -> bool:
	return unlocked_behaviors.has(behavior_id)


func get_death_count(cause: String) -> int:
	return death_counts.get(cause, 0)


func get_hit_count(cause: String) -> int:
	return mechanic_hit_counts.get(cause, 0)


func _on_hero_died(_hero: CharacterBody2D, cause: String) -> void:
	death_counts[cause] = death_counts.get(cause, 0) + 1
	_check_unlocks(cause)
	_persist()


func _on_hero_damaged(_hero: CharacterBody2D, _amount: float, source_type: String) -> void:
	if source_type not in MECHANIC_CAUSES:
		return
	mechanic_hit_counts[source_type] = mechanic_hit_counts.get(source_type, 0) + 1
	_check_unlocks(source_type)
	_persist()


func _check_unlocks(cause: String) -> void:
	if not UNLOCK_THRESHOLDS.has(cause):
		return
	var threshold: Dictionary = UNLOCK_THRESHOLDS[cause]
	var behavior_id: String = threshold["behavior"]
	if is_unlocked(behavior_id):
		return
	var deaths_required: int = threshold.get("deaths_required", 999)
	var hits_required: int = threshold.get("hits_required", 999)
	if get_death_count(cause) >= deaths_required or get_hit_count(cause) >= hits_required:
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
			"mechanic_hit_counts": mechanic_hit_counts.duplicate(),
		}
	})


func _on_game_reset() -> void:
	_load_from_save(SaveManager.load_data())


func _load_from_save(data: Dictionary) -> void:
	var unlock_data: Dictionary = data.get("unlock_data", {})
	unlocked_behaviors = unlock_data.get("unlocked_behaviors", {})
	death_counts = unlock_data.get("death_counts", {})
	mechanic_hit_counts = unlock_data.get("mechanic_hit_counts", {})
