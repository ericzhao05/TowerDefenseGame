# Scripts/ui/tower_button.gd
extends Button  # This is correct - Button inherits from Control

signal tower_button_pressed(tower_type, cost)

var tower_type: String
var cost: int
var tower_name: String

@onready var icon_texture = $TextureRect
@onready var cost_label = $CostLabel
@onready var name_label = $NameLabel

func _ready():
	# Connect the button's built-in pressed signal
	pressed.connect(_on_pressed)
	
	# Update UI elements
	if cost_label:
		cost_label.text = "$" + str(cost)
	if name_label:
		name_label.text = tower_name

func _on_pressed():
	emit_signal("tower_button_pressed", tower_type, cost)
