# Scripts/ui/tower_info.gd
extends Panel

var current_tower = null
var game_manager = null
var grid_manager = null

@onready var tower_name_label = $TowerNameLabel
@onready var tower_level_label = $TowerLevelLabel
@onready var upgrade_button = $UpgradeButton
@onready var upgrade_cost_label = $UpgradeCostLabel
@onready var sell_button = $SellButton

func _ready():
	# Find GameManager (grandparent)
	game_manager = get_parent().get_parent()  # UI → GameManager
	
	# Find GridManager (sibling through GameManager)
	if game_manager:
		grid_manager = game_manager.get_node("GridManager")
	
	# Connect button signals
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	
	# Hide initially
	hide()
	
	if game_manager:
		print("✅ TowerInfo: GameManager found")
	if grid_manager:
		print("✅ TowerInfo: GridManager found")

func show_tower_info(tower):
	current_tower = tower
	show()
	
	tower_name_label.text = tower.tower_name
	tower_level_label.text = "Level: " + str(tower.level)
	
	var upgrade_cost = tower.get_upgrade_cost()
	if upgrade_cost > 0:
		upgrade_button.disabled = false
		upgrade_cost_label.text = "Cost: $" + str(upgrade_cost)
		
		if game_manager and game_manager.currency < upgrade_cost:
			upgrade_button.modulate = Color(1, 0.5, 0.5)
		else:
			upgrade_button.modulate = Color.WHITE
	else:
		upgrade_button.disabled = true
		upgrade_cost_label.text = "MAX LEVEL"
	
	var sell_value = get_sell_value(tower)
	sell_button.text = "SELL ($" + str(sell_value) + ")"

func get_sell_value(tower):
	return int(tower.cost / 2 * tower.level)

func _on_upgrade_pressed():
	if not game_manager or not current_tower:
		return
	
	var upgrade_cost = current_tower.get_upgrade_cost()
	if upgrade_cost <= 0:
		return
	
	if game_manager.currency >= upgrade_cost:
		game_manager.currency -= upgrade_cost
		current_tower.upgrade()
		show_tower_info(current_tower)
		print("Tower upgraded to level ", current_tower.level)
	else:
		upgrade_button.modulate = Color.RED
		await get_tree().create_timer(0.2).timeout
		upgrade_button.modulate = Color(1, 0.5, 0.5)
		await get_tree().create_timer(0.2).timeout
		upgrade_button.modulate = Color.WHITE

func _on_sell_pressed():
	if not game_manager or not current_tower or not grid_manager:
		return
	
	# Calculate refund
	var sell_value = get_sell_value(current_tower)
	var grid_pos = current_tower.grid_pos
	
	# Add currency
	game_manager.currency += sell_value
	
	# Remove tower
	current_tower.queue_free()
	
	# Update grid
	if grid_manager:
		# Find the tile and mark it unoccupied
		for tile in grid_manager.grid_cells:
			if tile.grid_pos == grid_pos:
				tile.set_occupied(false)
				break
		
		# Remove from placed_towers
		var cell_key = str(grid_pos.x) + "," + str(grid_pos.y)
		if grid_manager.placed_towers.has(cell_key):
			grid_manager.placed_towers.erase(cell_key)
	
	current_tower = null
	hide()
	print("Tower sold for $", sell_value)
