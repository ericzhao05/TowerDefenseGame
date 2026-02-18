# UI/shop_manager.gd
# Manages the tower shop - generating random towers, handling purchases, and refreshing
extends Control

signal purchase_tower(tower_type, button)
signal refresh_shop

const REFRESH_COST = 3  # Gems needed to refresh

# Available tower types
var available_towers = [
	{"type": "TowerBase", "cost": 50,  "name": "Base Tower"},
	{"type": "SlowTower", "cost": 75,  "name": "Slow Tower"},
	{"type": "aoe_tower", "cost": 100, "name": "AOE Tower"}
]

var current_shop_towers = []  # Current 3 towers in shop
var is_first_generation: bool = true   # First gen is always one of each type

@onready var button_container = $ButtonContainer
@onready var not_enough_money_label = $NotEnoughMoneyLabel
@onready var refresh_button = get_node_or_null("RefreshButton")
var game_manager = null

func _ready():
	game_manager = get_node("/root/Main/GameManager")
	
	# First generation always shows one of each tower (tutorial-friendly)
	generate_shop()
	
	# Connect refresh button
	if refresh_button:
		refresh_button.pressed.connect(_on_refresh_pressed)
	
	# Hide the "not enough money" label initially
	if not_enough_money_label:
		not_enough_money_label.hide()

func generate_shop():
	# Clear existing buttons
	for child in button_container.get_children():
		child.queue_free()
	
	current_shop_towers.clear()
	
	# Stall positions
	var stall_positions = [
		Vector2(75, 130),    # Left stall (ORANGE awning)
		Vector2(331, 130),   # Middle stall (BROWN awning)
		Vector2(588, 130)    # Right stall (BLUE awning)
	]
	
	# First generation: always one of each tower type (Base, Slow, AOE)
	# Subsequent generations (after refresh): random
	var towers_to_show: Array = []
	if is_first_generation:
		is_first_generation = false
		towers_to_show = available_towers.duplicate()   # Exactly [Base, Slow, AOE]
	else:
		for _i in range(3):
			towers_to_show.append(available_towers[randi() % available_towers.size()].duplicate())
	
	for i in range(3):
		var tower_data = towers_to_show[i].duplicate()
		current_shop_towers.append(tower_data)
		
		var slot = preload("res://UI/TowerSlot.tscn").instantiate()
		button_container.add_child(slot)
		
		# Position manually
		slot.position = stall_positions[i]
		
		slot.setup(tower_data.type, tower_data.cost, tower_data.name)
		slot.tower_slot_clicked.connect(_on_tower_slot_clicked.bind(slot))

func _on_tower_slot_clicked(tower_type: String, cost: int, slot: Button):
	# Check if player has enough money
	if game_manager and game_manager.currency >= cost:
		# Emit signal with the slot reference so we can remove it
		emit_signal("purchase_tower", tower_type, slot)
	else:
		show_not_enough_money()

func remove_tower_slot(slot: Button):
	# Remove the purchased tower from shop
	if slot and is_instance_valid(slot):
		slot.queue_free()

func _on_refresh_pressed():
	if not game_manager:
		return
	
	if game_manager.gems >= REFRESH_COST:
		game_manager.gems -= REFRESH_COST
		generate_shop()
		print("Shop refreshed! Gems remaining:", game_manager.gems)
	else:
		show_not_enough_gems()

func show_not_enough_money():
	if not_enough_money_label:
		not_enough_money_label.text = "Not Enough Money!"
		not_enough_money_label.show()
		await get_tree().create_timer(1.0).timeout
		not_enough_money_label.hide()

func show_not_enough_gems():
	if not_enough_money_label:
		not_enough_money_label.text = "Not Enough Gems!"
		not_enough_money_label.show()
		await get_tree().create_timer(1.0).timeout
		not_enough_money_label.hide()
