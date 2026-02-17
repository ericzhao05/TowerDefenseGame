# Scripts/ui/tower_shop.gd
extends Control

signal purchase_tower(tower_type)

var tower_buttons = {
	"SlowTower": {"cost": 75, "icon": null, "name": "Slow Tower"},
	"SingleTargetTower": {"cost": 100, "icon": null, "name": "Single Target"},
	"AoeTower": {"cost": 125, "icon": null, "name": "AOE Tower"}
}

@onready var button_container = $ButtonContainer
@onready var not_enough_money_label = $NotEnoughMoneyLabel
@onready var game_manager = get_node("/root/Main/GameManager")

func _ready():
	# Create buttons dynamically
	for tower_type in tower_buttons:
		var button = preload("res://UI/tower_button.tscn").instantiate()
		button.tower_type = tower_type
		button.cost = tower_buttons[tower_type].cost
		button.tower_name = tower_buttons[tower_type].name
		# Connect to the renamed signal
		button.tower_button_pressed.connect(_on_tower_button_pressed)
		button_container.add_child(button)
	
	# Hide the "not enough money" label initially
	if not_enough_money_label:
		not_enough_money_label.hide()

func _on_tower_button_pressed(tower_type: String, cost: int):
	# Check if game_manager exists and has enough currency
	if game_manager and game_manager.currency >= cost:
		emit_signal("purchase_tower", tower_type)
		game_manager.currency -= cost
	else:
		show_not_enough_money()

func show_not_enough_money():
	if not_enough_money_label:
		not_enough_money_label.show()
		await get_tree().create_timer(1.0).timeout
		not_enough_money_label.hide()

# Optional: Update button states based on available currency
func update_button_states():
	var current_currency = game_manager.currency if game_manager else 0
	
	for button in button_container.get_children():
		if button.has_method("set_disabled"):
			button.disabled = button.cost > current_currency
