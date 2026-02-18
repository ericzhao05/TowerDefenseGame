# Scripts/grid_manager.gd
extends Node2D

signal tower_placed(tower_type, grid_pos)
signal tower_selected(tower)

const GRID_SIZE = 32  # Match your tile size!
const GRID_WIDTH = 40  # Adjust based on your map size
const GRID_HEIGHT = 32  # Adjust based on your map size

var placed_towers = {}
var current_drag_tower = null
var drag_tower_type = null
var drag_active = false
var grid_overlay: Node2D = null

@onready var game_manager = get_node("/root/Main/GameManager")
@onready var tilemap: TileMap = get_parent().get_node_or_null("Map")

func _ready():
	# Create grid overlay for visual feedback
	grid_overlay = Node2D.new()
	grid_overlay.name = "GridOverlay"
	grid_overlay.z_index = 100  # Draw on top
	grid_overlay.visible = false
	add_child(grid_overlay)
	print("GridManager ready with TileMap integration")
	
func _process(delta):
	if drag_active and current_drag_tower:
		# Update drag tower position to follow mouse
		var mouse_pos = get_global_mouse_position()
		update_drag_position(mouse_pos)
		
		# Update grid overlay
		grid_overlay.queue_redraw()

func start_drag(tower_type):
	# Check if player has enough money first
	var tower_cost = get_tower_cost(tower_type)
	if game_manager and game_manager.currency < tower_cost:
		print("Not enough money! Need $" + str(tower_cost) + ", have $" + str(game_manager.currency))
		return
	
	if drag_active:
		stop_drag()
	
	drag_tower_type = tower_type
	drag_active = true
	
	# Create ghost tower
	var tower_path = "res://Towers/" + tower_type + ".tscn"
	current_drag_tower = load(tower_path).instantiate()
	current_drag_tower.modulate = Color(1, 1, 1, 0.6)
	current_drag_tower.process_mode = PROCESS_MODE_DISABLED  # Disable tower logic while dragging
	
	# Hide health labels on ghost tower
	var health_label = current_drag_tower.get_node_or_null("TowerLevel")
	if health_label:
		health_label.visible = false
	
	add_child(current_drag_tower)
	
	# Show grid overlay
	grid_overlay.visible = true
	setup_grid_overlay_drawing()
	
	# Change cursor
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	print("Started dragging:", tower_type)

func setup_grid_overlay_drawing():
	# Connect draw function to grid overlay
	if not grid_overlay.draw.is_connected(_draw_grid):
		grid_overlay.draw.connect(_draw_grid)

func _draw_grid():
	if not drag_active or not current_drag_tower:
		return
	
	var mouse_pos = get_global_mouse_position()
	var tile_pos = tilemap.local_to_map(mouse_pos)
	
	# Draw grid in visible area around mouse
	var grid_radius = 15  # How many tiles to show around mouse
	for x in range(tile_pos.x - grid_radius, tile_pos.x + grid_radius):
		for y in range(tile_pos.y - grid_radius, tile_pos.y + grid_radius):
			var cell_pos = Vector2i(x, y)
			var world_pos = tilemap.map_to_local(cell_pos)
			
			# Check if this tile is buildable
			var is_buildable = check_tile_buildable(cell_pos)
			var has_tower = is_cell_occupied(cell_pos)
			
			var color = Color.GREEN
			if has_tower:
				color = Color.RED
			elif not is_buildable:
				color = Color.ORANGE
			
			# Highlight the tile under mouse cursor
			if cell_pos == tile_pos:
				color.a = 0.5
				# Draw filled rect for current tile
				var rect_pos = world_pos - Vector2(GRID_SIZE/2, GRID_SIZE/2)
				grid_overlay.draw_rect(Rect2(rect_pos, Vector2(GRID_SIZE, GRID_SIZE)), color)
			else:
				color.a = 0.2
			
			# Draw grid lines
			var rect_pos = world_pos - Vector2(GRID_SIZE/2, GRID_SIZE/2)
			grid_overlay.draw_rect(Rect2(rect_pos, Vector2(GRID_SIZE, GRID_SIZE)), color, false, 1.0)

func update_drag_position(world_pos):
	if current_drag_tower:
		var snapped_pos = snap_to_grid(world_pos)
		current_drag_tower.position = snapped_pos
		
		# Update tower color based on validity
		var tile_pos = tilemap.local_to_map(world_pos)
		var is_buildable = check_tile_buildable(tile_pos)
		var has_tower = is_cell_occupied(tile_pos)
		
		if has_tower or not is_buildable:
			current_drag_tower.modulate = Color(1, 0.3, 0.3, 0.6)  # Red = invalid
		else:
			current_drag_tower.modulate = Color(0.3, 1, 0.3, 0.6)  # Green = valid

func stop_drag():
	if current_drag_tower:
		current_drag_tower.queue_free()
		current_drag_tower = null
	
	drag_tower_type = null
	drag_active = false
	
	# Hide grid overlay
	if grid_overlay:
		grid_overlay.visible = false
	
	# Reset cursor
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	print("Stopped dragging")

func check_tile_buildable(tile_pos: Vector2i) -> bool:
	if not tilemap:
		return false
	
	# Get tile data
	var tile_data = tilemap.get_cell_tile_data(0, tile_pos)  # Layer 0
	if not tile_data:
		return false
	
	# Check custom data layers
	var is_buildable = tile_data.get_custom_data("is_buildable")
	var is_path = tile_data.get_custom_data("is_path")
	var is_not_buildable = tile_data.get_custom_data("is_not_buildable")
	
	# Can build if is_buildable is true AND is_path is false AND is_not_buildable is false
	return is_buildable and not is_path and not is_not_buildable

func is_cell_occupied(tile_pos: Vector2i) -> bool:
	var cell_key = str(tile_pos.x) + "," + str(tile_pos.y)
	return placed_towers.has(cell_key)

func snap_to_grid(pos):
	if not tilemap:
		return pos
	var tile_pos = tilemap.local_to_map(pos)
	return tilemap.map_to_local(tile_pos)

func get_grid_pos(pos):
	if not tilemap:
		return Vector2i(0, 0)
	return tilemap.local_to_map(pos)

func place_tower(tower_type, tile_pos: Vector2i):
	print("========== PLACE TOWER ==========")
	print("Attempting:", tower_type, "at tile:", tile_pos)
	
	# Check 1: Is tile buildable?
	if not check_tile_buildable(tile_pos):
		print("FAIL: Tile not buildable")
		return false
	
	# Check 2: Is cell occupied?
	if is_cell_occupied(tile_pos):
		print("FAIL: Cell already occupied")
		return false
	
	# Check 3: Get tower cost
	var tower_cost = get_tower_cost(tower_type)
	
	# Check 4: Check currency
	if game_manager:
		if game_manager.currency < tower_cost:
			print("FAIL: Not enough money")
			return false
	
	# Check 5: Load and instantiate tower
	var tower_path = "res://Towers/" + tower_type + ".tscn"
	if not ResourceLoader.exists(tower_path):
		print("FAIL: Tower scene doesn't exist:", tower_path)
		return false
	
	var tower = load(tower_path).instantiate()
	if not tower:
		print("FAIL: Failed to instantiate tower")
		return false
	
	# Set position using TileMap
	var world_pos = tilemap.map_to_local(tile_pos)
	tower.position = world_pos
	
	# Hide health/level label
	var health_label = tower.get_node_or_null("TowerLevel")
	if health_label:
		health_label.visible = false
	
	# Add as child
	add_child(tower)
	
	# Mark as placed
	var cell_key = str(tile_pos.x) + "," + str(tile_pos.y)
	placed_towers[cell_key] = tower
	
	# Deduct currency
	if game_manager:
		game_manager.currency -= tower_cost
	
	emit_signal("tower_placed", tower_type, tile_pos)
	print("SUCCESS: Tower placed!")
	print("=================================")
	return true

func get_tower_cost(tower_type):
	match tower_type:
		"TowerBase":
			return 50
		"SlowTower":
			return 75
		_:
			return 50

func _input(event):
	# Handle mouse clicks for tower placement
	if drag_active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var tile_pos = tilemap.local_to_map(mouse_pos)
		
		if place_tower(drag_tower_type, tile_pos):
			stop_drag()
	
	# Cancel with right click or ESC
	if drag_active and event.is_action_pressed("ui_cancel"):
		stop_drag()
	if drag_active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		stop_drag()
