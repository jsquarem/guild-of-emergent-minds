extends Node
## Global signal bus for decoupled communication between systems.

signal hero_damaged(hero: CharacterBody2D, amount: float, source_type: String)
signal hero_died(hero: CharacterBody2D, cause: String)
signal hazard_entered(hero: CharacterBody2D, hazard_type: String)
signal hazard_exited(hero: CharacterBody2D, hazard_type: String)
signal behavior_unlocked(behavior_id: String)
signal dungeon_completed()
signal dungeon_failed()
signal run_started()
signal run_ended(success: bool)
signal speed_changed(new_speed: float)
signal mechanic_telegraph(mechanic_id: String, data: Dictionary)
signal mechanic_triggered(mechanic_id: String, data: Dictionary)
signal game_reset()
signal room_cleared(room_index: int)
