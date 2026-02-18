# Scripts/enemy_spawner_example.gd
# This is an EXAMPLE script showing how to spawn different enemy types
# Copy the relevant parts into your GameManager or wave spawner script

extends Node

# Preload all enemy types
var enemy_types = {
	"basic": preload("res://Enemies/Enemy.tscn"),
	"fast": preload("res://Enemies/FastEnemy.tscn"),
	"tank": preload("res://Enemies/TankEnemy.tscn"),
	"boss": preload("res://Enemies/BossEnemy.tscn")
}

# Reference to your path (adjust as needed)
@onready var enemy_path = $Path2D
@onready var path_follow = $Path2D/PathFollow2D

var current_wave = 1

# Example 1: Spawn a specific enemy type
func spawn_enemy(enemy_type: String = "basic"):
	if not enemy_types.has(enemy_type):
		print("Unknown enemy type: ", enemy_type)
		return null
	
	var enemy = enemy_types[enemy_type].instantiate()
	
	# Initialize with current wave
	enemy.initialize(current_wave)
	
	# Create a PathFollow2D for this enemy
	var follow = PathFollow2D.new()
	enemy_path.add_child(follow)
	follow.add_child(enemy)
	
	# Store reference
	enemy.path_follow = follow
	
	# Connect signals
	enemy.enemy_died.connect(_on_enemy_died)
	enemy.enemy_reached_end.connect(_on_enemy_reached_end)
	
	return enemy

# Example 2: Spawn random enemy type
func spawn_random_enemy():
	var types = ["basic", "fast", "tank"]
	var random_type = types[randi() % types.size()]
	return spawn_enemy(random_type)

# Example 3: Spawn a wave with mixed enemies
func spawn_wave(wave_number: int):
	current_wave = wave_number
	var num_enemies = 5 + (wave_number * 2)
	
	# Boss wave every 5 waves
	if wave_number % 5 == 0:
		print("Boss wave!")
		for i in range(3):
			spawn_enemy("boss")
			await get_tree().create_timer(2.0).timeout
	else:
		# Mix of regular enemies
		for i in range(num_enemies):
			var enemy_type = choose_enemy_for_wave(wave_number)
			spawn_enemy(enemy_type)
			await get_tree().create_timer(1.0).timeout

# Example 4: Smart enemy selection based on wave
func choose_enemy_for_wave(wave_number: int) -> String:
	# Early waves: only basic enemies
	if wave_number <= 2:
		return "basic"
	
	# Mid waves: introduce fast enemies
	elif wave_number <= 5:
		var types = ["basic", "fast"]
		return types[randi() % types.size()]
	
	# Later waves: add tanks
	elif wave_number <= 10:
		var types = ["basic", "fast", "tank"]
		var weights = [50, 30, 20]  # % chance
		return weighted_random_enemy(types, weights)
	
	# Late game: all types with more tanks
	else:
		var types = ["basic", "fast", "tank"]
		var weights = [30, 30, 40]  # More tanks in late game
		return weighted_random_enemy(types, weights)

# Example 5: Weighted random selection
func weighted_random_enemy(types: Array, weights: Array) -> String:
	var total = 0
	for w in weights:
		total += w
	
	var rand = randi() % total
	var current = 0
	
	for i in range(types.size()):
		current += weights[i]
		if rand < current:
			return types[i]
	
	return types[0]

# Example 6: Spawn pattern (alternating types)
func spawn_alternating_pattern():
	var pattern = ["basic", "basic", "fast", "basic", "tank"]
	
	for enemy_type in pattern:
		spawn_enemy(enemy_type)
		await get_tree().create_timer(1.5).timeout

# Example 7: Difficulty scaling
func spawn_scaled_wave(wave_number: int):
	current_wave = wave_number
	
	# Calculate difficulty
	var difficulty = wave_number / 5.0
	
	# More enemies based on difficulty
	var num_enemies = int(5 + (difficulty * 3))
	
	# Higher chance of tough enemies
	var tank_chance = min(0.4, difficulty * 0.1)  # Up to 40%
	var fast_chance = 0.3
	var basic_chance = 1.0 - tank_chance - fast_chance
	
	for i in range(num_enemies):
		var rand = randf()
		var enemy_type = "basic"
		
		if rand < tank_chance:
			enemy_type = "tank"
		elif rand < (tank_chance + fast_chance):
			enemy_type = "fast"
		
		spawn_enemy(enemy_type)
		await get_tree().create_timer(1.0).timeout

# Signal handlers (connect these to your game manager)
func _on_enemy_died(worth):
	print("Enemy died, worth: ", worth)
	# Add gold/score here
	# Global.gold += worth

func _on_enemy_reached_end():
	print("Enemy reached end!")
	# Reduce lives here
	# Global.lives -= 1

# Example usage in your _ready or start_game function:
func _ready():
	# Example: Start with wave 1
	await get_tree().create_timer(1.0).timeout
	spawn_wave(1)

# Example: Button to start next wave
func _on_next_wave_button_pressed():
	current_wave += 1
	spawn_wave(current_wave)

