# Scripts/aoe_tower.gd
extends "res://Scripts/tower_base.gd"

@export var aoe_radius: float = 50.0

func _ready():
	tower_name = "AOE Tower"
	cost = 125
	range_radius = 120.0
	attack_cooldown = 2.5
	_ready()

func attack(target):
	for enemy in enemies_in_range:
		if enemy.global_position.distance_to(target.global_position) <= aoe_radius:
			if is_instance_valid(enemy):
				enemy.take_damage(base_damage)

func select_target():
	# Target the most clustered area
	if enemies_in_range.size() == 0:
		return null
	
	var best_target = enemies_in_range[0]
	var max_nearby = 0
	
	for enemy in enemies_in_range:
		var nearby_count = 0
		for other in enemies_in_range:
			if enemy.global_position.distance_to(other.global_position) <= aoe_radius:
				nearby_count += 1
		
		if nearby_count > max_nearby:
			max_nearby = nearby_count
			best_target = enemy
	
	return best_target

func apply_upgrade_stats():
	match level:
		2:
			aoe_radius = 70.0
			base_damage = 15
		3:
			aoe_radius = 100.0
			base_damage = 20
