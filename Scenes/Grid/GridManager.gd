# Scripts/grid_manager.gd
extends Node2D

signal tower_placed(tower_type, grid_pos)
signal tower_selected(tower)

const GRID_SIZE = 64
const GRID_WIDTH = 10
const GRID_HEIGHT = 8

var grid_cells = []
var placed_towers = {}
var current_drag_tower = null
var drag_tower_type = null
var drag_active = false

@onready var tile_scene = preload("res://Scenes/Grid/Tile.tscn")
@onready var game_manager = get_node("/root/Main/GameManager")  # Adjust path as needed

func _ready():
	initialize_grid()
	
func _process(delta):
	if drag_active and current_drag_tower:
		# Update drag tower position to follow mouse
		var mouse_pos = get_global_mouse_position()
		update_drag_position(mouse_pos)
		
		# Check if we're over a valid tile
		var grid_pos = get_grid_pos(mouse_pos)
		highlight_valid_placement(grid_pos)

func initialize_grid():
	print("=== Initializing Grid ===")
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var tile = tile_scene.instantiate()
			tile.position = Vector2(x * GRID_SIZE, y * GRID_SIZE)
			tile.grid_pos = Vector2(x, y)
			
			# Connect signals with debug
			print("Connecting tile at (", x, ",", y, ")")
			tile.tile_clicked.connect(_on_tile_clicked)
			tile.tile_mouse_entered.connect(_on_tile_mouse_entered)
			tile.tile_mouse_exited.connect(_on_tile_mouse_exited)
			
			add_child(tile)
			grid_cells.append(tile)
	print("Grid initialized with ", grid_cells.size(), " tiles")

func start_drag(tower_type):
	if drag_active:
		stop_drag()
	
	drag_tower_type = tower_type
	drag_active = true
	
	# Create ghost tower
	var tower_path = "res://Towers/" + tower_type + ".tscn"
	current_drag_tower = load(tower_path).instantiate()
	current_drag_tower.modulate = Color(1, 1, 1, 0.5)
	current_drag_tower.is_ghost = true
	current_drag_tower.process_mode = PROCESS_MODE_DISABLED  # Disable tower logic while dragging
	add_child(current_drag_tower)
	
	# Change cursor
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)

func update_drag_position(world_pos):
	if current_drag_tower:
		current_drag_tower.position = snap_to_grid(world_pos)

func stop_drag():
	if current_drag_tower:
		current_drag_tower.queue_free()
		current_drag_tower = null
	
	drag_tower_type = null
	drag_active = false
	
	# Reset cursor
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	
	# Reset all tile highlights
	for tile in grid_cells:
		tile.reset_color()

func highlight_valid_placement(grid_pos):
	# Reset all tiles first
	for tile in grid_cells:
		tile.reset_color()
	
	# Highlight the tile under mouse
	for tile in grid_cells:
		if tile.grid_pos == grid_pos:
			if is_cell_available(grid_pos):
				tile.show_valid_placement()
			else:
				tile.show_invalid_placement()
			break

func snap_to_grid(pos):
	var grid_x = round(pos.x / GRID_SIZE) * GRID_SIZE
	var grid_y = round(pos.y / GRID_SIZE) * GRID_SIZE
	return Vector2(grid_x, grid_y)

func get_grid_pos(pos):
	var x = round(pos.x / GRID_SIZE)
	var y = round(pos.y / GRID_SIZE)
	return Vector2(x, y)

func is_cell_available(grid_pos):
	return !placed_towers.has(grid_pos) and grid_pos.x >= 0 and grid_pos.x < GRID_WIDTH and grid_pos.y >= 0 and grid_pos.y < GRID_HEIGHT

func place_tower(tower_type, grid_pos):
	print("========== PLACE TOWER DEBUG ==========")
	print("Attempting to place: ", tower_type, " at ", grid_pos)
	
	# Check 1: Cell availability
	if !is_cell_available(grid_pos):
		print("❌ FAIL: Cell not available")
		return false
	print("✅ Cell available")
	
	# Check 2: Get tower cost
	var tower_cost = get_tower_cost(tower_type)
	print("Tower cost: ", tower_cost)
	
	# Check 3: Check currency (if you have game_manager reference)
	if game_manager:
		print("Current currency: ", game_manager.currency)
		if game_manager.currency < tower_cost:
			print("❌ FAIL: Not enough money")
			return false
		print("✅ Enough money")
	else:
		print("⚠️ WARNING: game_manager not found, skipping currency check")
	
	# Check 4: Tower scene path
	var tower_path = "res://Towers/" + tower_type + ".tscn"
	print("Loading from: ", tower_path)
	
	if not ResourceLoader.exists(tower_path):
		print("❌ FAIL: Tower scene doesn't exist at: ", tower_path)
		return false
	print("✅ Tower scene exists")
	
	# Check 5: Instantiate tower
	var tower = load(tower_path).instantiate()
	if not tower:
		print("❌ FAIL: Failed to instantiate tower")
		return false
	print("✅ Tower instantiated: ", tower)
	
	# Check 6: Set position
	tower.position = grid_pos * GRID_SIZE
	print("Position set to: ", tower.position)
	
	# Check 7: Connect signal
	tower.tower_clicked.connect(_on_tower_clicked)
	print("✅ Signal connected")
	
	# Check 8: Add as child
	add_child(tower)
	print("✅ Tower added as child")
	
	# Check 9: Mark as placed
	var cell_key = str(grid_pos.x) + "," + str(grid_pos.y)
	placed_towers[cell_key] = tower
	print("✅ Tower recorded in placed_towers")
	
	# Check 10: Mark tile as occupied
	var tile_found = false
	for tile in grid_cells:
		if tile.grid_pos == grid_pos:
			tile.set_occupied(true)
			tile_found = true
			print("✅ Tile marked occupied")
			break
	if not tile_found:
		print("⚠️ WARNING: No tile found at ", grid_pos)
	
	# Check 11: Deduct currency (if game_manager exists)
	if game_manager:
		game_manager.currency -= tower_cost
		print("✅ Currency deducted, new balance: ", game_manager.currency)
	
	emit_signal("tower_placed", tower_type, grid_pos)
	print("✅ Tower placed successfully!")
	print("=====================================")
	return true

func get_tower_cost(tower_type):
	match tower_type:
		"SlowTower":
			return 75
		"SingleTargetTower":
			return 100
		"AoeTower":
			return 125
		_:
			return 50

func _on_tile_clicked(tile):
	print("*** TILE CLICKED *** at grid position: ", tile.grid_pos)
	print("  drag_active: ", drag_active)
	print("  drag_tower_type: ", drag_tower_type)
	print("  cell available? ", is_cell_available(tile.grid_pos))
	
	if drag_active and is_cell_available(tile.grid_pos):
		print("  Attempting to place tower...")
		if place_tower(drag_tower_type, tile.grid_pos):
			print("  Tower placed successfully!")
			stop_drag()  # Successfully placed, stop dragging
		else:
			print("  Failed to place tower")
	else:
		if not drag_active:
			print("  Not in drag mode")
		if not is_cell_available(tile.grid_pos):
			print("  Cell not available")
			

func _on_tower_clicked(tower):
	emit_signal("tower_selected", tower)

func _on_tile_mouse_entered(tile):
	if drag_active:
		highlight_valid_placement(tile.grid_pos)

func _on_tile_mouse_exited(tile):
	# Don't reset immediately to avoid flickering
	pass

func _input(event):
	if drag_active and event.is_action_pressed("ui_cancel"):  # Press ESC to cancel
		stop_drag()
