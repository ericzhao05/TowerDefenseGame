# Scripts/level_label.gd
extends Label

@export var level_name: String = "Level 1"
@export var show_duration: float = 3.0  # How long to show the label
@export var fade_duration: float = 1.0  # How long to fade out

func _ready():
	text = level_name
	modulate.a = 0.0  # Start invisible
	
	# Fade in
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	tween.tween_interval(show_duration)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(queue_free)  # Remove after fade

# Or use this for permanent label (comment out the tween above):
# func _ready():
# 	text = level_name

