# Scripts/tile.gd
extends Area2D

signal tile_clicked(tile)
signal tile_mouse_entered(tile)
signal tile_mouse_exited(tile)

# This variable MUST be defined at the top of the script
var grid_pos: Vector2
var is_occupied: bool = false

# Color variables
var default_color = Color(1, 1, 1, 0.3)
var hover_color = Color(0.8, 0.8, 0.8, 0.5)
var occupied_color = Color(1, 0.3, 0.3, 0.4)
var valid_placement_color = Color(0.3, 1, 0.3, 0.5)
var invalid_placement_color = Color(1, 0.3, 0.3, 0.5)

@onready var color_rect = $ColorRect
@onready var label = $CoordinatesLabel if has_node("CoordinatesLabel") else null

func _ready():
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	update_color()
	
	if label:
		label.text = str(grid_pos.x) + "," + str(grid_pos.y)

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("tile_clicked", self)

func _on_mouse_entered():
	emit_signal("tile_mouse_entered", self)
	if not is_occupied:
		update_color(true)

func _on_mouse_exited():
	emit_signal("tile_mouse_exited", self)
	update_color()

func set_occupied(occupied: bool):
	is_occupied = occupied
	update_color()

func update_color(hovered: bool = false):
	if is_occupied:
		color_rect.color = occupied_color
	elif hovered:
		color_rect.color = hover_color
	else:
		color_rect.color = default_color

func show_valid_placement():
	color_rect.color = valid_placement_color
	
func show_invalid_placement():
	color_rect.color = invalid_placement_color
	
func reset_color():
	update_color()
