extends Node
## Handles reading and writing the single save file. Pure I/O — no game-logic awareness.

const SAVE_PATH: String = "user://save_data.json"

var _cache: Dictionary = {}


func _ready() -> void:
	_cache = _read_from_disk()


func save_data(data: Dictionary) -> void:
	_cache.merge(data, true)
	_write_to_disk(_cache)


func load_data() -> Dictionary:
	return _cache


func reset_to_default() -> void:
	_cache = {
		"run_count": 0,
		"unlock_data": {
			"unlocked_behaviors": {},
			"death_counts": {},
			"mechanic_hit_counts": {},
		}
	}
	_write_to_disk(_cache)


func _read_from_disk() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		return json.data
	return {}


func _write_to_disk(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
