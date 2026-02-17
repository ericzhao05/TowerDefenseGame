# Scripts/tower_base.gd
extends Area2D

signal tower_clicked(tower)

@export var tower_name: String = "Tower"
@export var cost: int = 50
@export var range_radius: float = 150.0
@export var attack_cooldown: float = 1.0
@export var base_damage: int = 10

var level: int = 1
var max_level: int = 3
var upgrade_cost: int = cost * 2
var is_ghost: bool = false
var grid_pos: Vector2
var current_target = null
var can_attack: bool = true
var enemies_in_range = []

@onready var range_shape = $Range
@onready var attack_timer = $AttackTimer
@onready var sprite = $Sprite2D

func _ready():
	print("Tower _ready: ", name, " is_ghost=", is_ghost)
	if !is_ghost:
		if range_shape and range_shape.shape:
			range_shape.shape.radius = range_radius
			print("  Range set to: ", range_radius)
		if attack_timer:
			attack_timer.wait_time = attack_cooldown
			attack_timer.start()
			print("  Attack timer set to: ", attack_cooldown)
		if sprite:
			print("  Sprite found")
		else:
			print("  WARNING: No sprite found!")

func _process(_delta):
	if is_ghost:
		return
	
	update_target()
	
	if current_target and can_attack and is_instance_valid(current_target):
		attack(current_target)
		can_attack = false
		attack_timer.start()

func update_target():
	if enemies_in_range.size() > 0:
		# Filter out dead enemies
		enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e))
		
		if enemies_in_range.size() > 0:
			current_target = select_target()
			return
	
	current_target = null

func select_target():
	# Base implementation - override in specific tower types
	if enemies_in_range.size() > 0:
		return enemies_in_range[0]
	return null

func attack(target):
	# Base implementation - override in specific tower types
	pass

func _on_Range_body_entered(body):
	if body.is_in_group("enemies"):
		enemies_in_range.append(body)

func _on_Range_body_exited(body):
	enemies_in_range.erase(body)

func _on_AttackTimer_timeout():
	can_attack = true

func _on_Tower_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("tower_clicked", self)

func get_upgrade_cost():
	if level < max_level:
		return upgrade_cost * level
	return -1

func upgrade():
	if level < max_level:
		level += 1
		apply_upgrade_stats()

func apply_upgrade_stats():
	# Override in specific towers
	pass
