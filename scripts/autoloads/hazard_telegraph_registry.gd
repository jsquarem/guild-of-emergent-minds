extends Node
## Tracks active hazard telegraphs (e.g. boss fire) so heroes can avoid them before they trigger.
## Listens to EventBus.mechanic_telegraph / mechanic_triggered.

var _fire_telegraph: Dictionary = {}


func _ready() -> void:
	EventBus.mechanic_telegraph.connect(_on_mechanic_telegraph)
	EventBus.mechanic_triggered.connect(_on_mechanic_triggered)


func _on_mechanic_telegraph(mechanic_id: String, data: Dictionary) -> void:
	if mechanic_id != "fire":
		return
	var duration: float = data.get("duration", 1.2)
	_fire_telegraph = {
		"position": data.get("position", Vector2.ZERO),
		"radius": data.get("radius", 50.0),
		"end_time": Time.get_ticks_msec() / 1000.0 + duration,
	}


func _on_mechanic_triggered(mechanic_id: String, _data: Dictionary) -> void:
	if mechanic_id == "fire":
		_fire_telegraph = {}


## Returns current fire telegraph if active and not expired; otherwise empty dict.
func get_current_fire_telegraph() -> Dictionary:
	if _fire_telegraph.is_empty():
		return {}
	var now: float = Time.get_ticks_msec() / 1000.0
	if now >= _fire_telegraph.get("end_time", 0.0):
		_fire_telegraph = {}
		return {}
	return _fire_telegraph
