# Scripts/slow_tower.gd
extends "res://Scripts/tower_base.gd"

@export var slow_amount: float = 0.5  # 50% slow
@export var slow_duration: float = 2.0

func _ready():
	tower_name = "Slow Tower"
	cost = 75
	range_radius = 120.0
	attack_cooldown = 2.0
	base_damage = 0.0
	
	super()

func attack(target):
	if is_instance_valid(target):
		target.apply_slow(slow_amount, slow_duration)

func select_target():
	# Can target any enemy in range
	return enemies_in_range[0]

func apply_upgrade_stats():
	match level:
		2:
			slow_amount = 0.7  # 70% slow
			range_radius = 140.0
		3:
			slow_amount = 0.9  # 90% slow
			range_radius = 160.0
	
	$Range/CollisionShape2D.shape.radius = range_radius
