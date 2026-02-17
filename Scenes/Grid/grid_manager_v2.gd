# Simplified GridManager for use with TileMap
extends Node2D

signal tower_placed(tower_type, grid_pos)
signal tower_selected(tower)

const GRID_SIZE = 64
const GRID_WIDTH = 10
const GRID_HEIGHT = 8

var placed_towers = {}
var current_drag_tower = null
var drag_tower_type = null
var drag_active = false

@onready var tile_map = $TileMapLayer  # Reference to your TileMapLayer
@onready var game_manager = get_node("/root/Main/GameManager")

func _process(delta):
	if drag_active and current_drag_tower:
		var mouse_pos = get_global_mouse_position()
		update_drag_position(mouse_pos)

func start_drag(tower_type):
	if drag_active:
		stop_drag()
	
	drag_tower_type = tower_type
	drag_active = true
	
	var tower_path = "res://Scenes/Towers/" + tower_type + ".tscn"
	current_drag_tower = load(tower_path).instantiate()
	current_drag_tower.modulate = Color(1, 1, 1, 0.5)
	current_drag_tower.is_ghost = true
	current_drag_tower.process_mode = PROCESS_MODE_DISABLED
	add_child(current_drag_tower)
	
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)

func update_drag_position(world_pos):
	if current_drag_tower:
		current_drag_tower.position = snap_to_grid(world_pos)

func snap_to_grid(pos):
	var grid_x = round(pos.x / GRID_SIZE) * GRID_SIZE
	var grid_y = round(pos.y / GRID_SIZE) * GRID_SIZE
	return Vector2(grid_x, grid_y)

func get_grid_pos(pos):
	var x = round(pos.x / GRID_SIZE)
	var y = round(pos.y / GRID_SIZE)
	return Vector2(x, y)

func is_cell_available(grid_pos):
	var cell_key = str(grid_pos.x) + "," + str(grid_pos.y)
	return !placed_towers.has(cell_key) and grid_pos.x >= 0 and grid_pos.x < GRID_WIDTH and grid_pos.y >= 0 and grid_pos.y < GRID_HEIGHT

func place_tower(tower_type, grid_pos):
	var cell_key = str(grid_pos.x) + "," + str(grid_pos.y)
	if !is_cell_available(grid_pos):
		return false
	
	var tower_cost = get_tower_cost(tower_type)
	if game_manager.currency < tower_cost:
		return false
	
	var tower_path = "res://Scenes/Towers/" + tower_type + ".tscn"
	var tower = load(tower_path).instantiate()
	tower.position = grid_pos * GRID_SIZE
	tower.grid_pos = grid_pos
	tower.tower_clicked.connect(_on_tower_clicked)
	add_child(tower)
	
	placed_towers[cell_key] = tower
	game_manager.currency -= tower_cost
	
	emit_signal("tower_placed", tower_type, grid_pos)
	return true

func stop_drag():
	if current_drag_tower:
		current_drag_tower.queue_free()
		current_drag_tower = null
	
	drag_tower_type = null
	drag_active = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func get_tower_cost(tower_type):
	match tower_type:
		"SlowTower": return 75
		"SingleTargetTower": return 100
		"AoeTower": return 125
		_: return 50

func _input(event):
	if drag_active and event.is_action_pressed("ui_cancel"):
		stop_drag()

func _on_tilemap_clicked(grid_pos):
	if drag_active and is_cell_available(grid_pos):
		if place_tower(drag_tower_type, grid_pos):
			stop_drag()

func _on_tower_clicked(tower):
	emit_signal("tower_selected", tower)
