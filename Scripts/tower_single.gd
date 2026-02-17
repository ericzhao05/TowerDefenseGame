# Scripts/single_tower.gd
extends "res://Scripts/tower_base.gd"

func _ready():
	tower_name = "Single Target Tower"
	cost = 100
	range_radius = 180.0
	attack_cooldown = 0.8
	_ready()

func attack(target):
	if is_instance_valid(target):
		target.take_damage(base_damage)

func select_target():
	# Find the furthest enemy in range
	var furthest_distance = 0
	var furthest_enemy = null
	
	for enemy in enemies_in_range:
		var distance = global_position.distance_to(enemy.global_position)
		if distance > furthest_distance:
			furthest_distance = distance
			furthest_enemy = enemy
	
	return furthest_enemy

func apply_upgrade_stats():
	match level:
		2:
			base_damage = 20
			attack_cooldown = 0.7
		3:
			base_damage = 35
			attack_cooldown = 0.6
