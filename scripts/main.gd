extends Node2D
## Project entry point. Loads the dungeon scene (and later other scenes: menu, hub, etc.).

func _ready() -> void:
	get_tree().change_scene_to_file("res://scenes/dungeon.tscn")
