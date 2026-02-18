# Scripts/level_manager.gd
extends Node2D

var current_level = null
var level_container = null

func _ready():
	level_container = $LevelContainer
	load_level("res://Scenes/Levels/Level1.tscn")

func load_level(level_path: String):
	# Clear current level
	if current_level:
		current_level.queue_free()
	
	# Load new level
	var level_scene = load(level_path)
	current_level = level_scene.instantiate()
	level_container.add_child(current_level)
	
	print("Loaded: ", level_path)

func next_level():
	# Load next level when current one is complete
	# load_level("res://Scenes/Levels/Level2.tscn")
	pass
