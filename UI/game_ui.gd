# Scripts/ui/game_ui.gd
extends CanvasLayer

@onready var currency_label = $TopBar/CurrencyLabel
@onready var wave_label = $TopBar/WaveLabel
@onready var tower_shop = $TowerShop
@onready var tower_info = $TowerInfo

# References
var game_manager = null
var grid_manager = null

func _ready():
	# Find GameManager (parent)
	game_manager = get_parent()  # UI's parent is GameManager
	
	# Find GridManager (sibling through parent)
	if game_manager:
		grid_manager = game_manager.get_node("GridManager")  # GridManager is child of GameManager
	
	if game_manager:
		# Connect to GameManager signals
		game_manager.currency_changed.connect(_on_currency_changed)
		game_manager.wave_completed.connect(_on_wave_completed)
		
		# Initialize display
		_on_currency_changed(game_manager.currency)
		print("✅ GameManager found")
	else:
		print("ERROR: GameManager not found in game_ui.gd")
	
	if grid_manager:
		grid_manager.tower_selected.connect(_on_tower_selected)
		print("✅ GridManager found")
	else:
		print("ERROR: GridManager not found in game_ui.gd")
	
	# Hide tower info panel initially
	if tower_info:
		tower_info.hide()

func _on_currency_changed(new_amount):
	if currency_label:
		currency_label.text = "$" + str(new_amount)

func _on_wave_completed():
	if wave_label and game_manager:
		wave_label.text = "Wave " + str(game_manager.current_wave) + " Complete!"
		wave_label.modulate = Color.YELLOW
		await get_tree().create_timer(1.0).timeout
		wave_label.modulate = Color.WHITE

func _on_tower_selected(tower):
	if tower_info:
		tower_info.show_tower_info(tower)
