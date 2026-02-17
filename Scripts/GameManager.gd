# Scripts/game_manager.gd
extends Node2D

signal currency_changed(new_amount)
signal wave_completed

var currency: int = 300 :
	set(value):
		currency = value
		emit_signal("currency_changed", currency)

var current_wave: int = 0
var enemies_alive: int = 0
var wave_in_progress: bool = false

@onready var grid_manager = $GridManager
@onready var path = $Path2D
@onready var enemy_spawner = $EnemySpawner
@onready var ui = $UI

func _ready():
	randomize()
	if ui and ui.has_node("TowerShop"):
		ui.get_node("TowerShop").purchase_tower.connect(_on_purchase_tower)
	
	start_wave()

func _on_purchase_tower(tower_type: String):
	# Tell grid manager to start drag mode
	if grid_manager:
		grid_manager.start_drag(tower_type)	
	else:
		print("ERROR: grid_manager not found!")

func start_wave():
	if wave_in_progress:
		return
	
	wave_in_progress = true
	current_wave += 1
	spawn_wave(current_wave)

# Scripts/game_manager.gd - Fixed spawn_wave

func spawn_wave(wave_number):
	# Safety check
	if not path or not path.curve or path.curve.get_point_count() == 0:
		push_error("Path has no points! Cannot spawn enemies.")
		return
	
	var enemy_count = 5 + wave_number * 2
	enemies_alive = enemy_count
	
	for i in range(enemy_count):
		var enemy = create_enemy(wave_number)
		
		enemy.enemy_died.connect(_on_enemy_died)
		enemy.enemy_reached_end.connect(_on_enemy_reached_end)
		
		# Create a PathFollow2D to control the enemy's position
		var path_follow = PathFollow2D.new()
		path_follow.name = "PathFollow_" + str(i)
		path_follow.rotates = false
		path_follow.loop = false
		
		# Add the enemy as a child of PathFollow2D
		path_follow.add_child(enemy)
		
		# Add the PathFollow2D to the Path2D
		path.add_child(path_follow)
		
		# Set the enemy's path_follow reference
		enemy.path_follow = path_follow
		
		# Position at start of path
		path_follow.progress = 0
		
		# Stagger spawn times
		await get_tree().create_timer(0.5).timeout

# In GameManager.gd - Fixed create_enemy function

func create_enemy(wave_number):
	var enemy = CharacterBody2D.new()
	enemy.name = "Enemy"
	
	# Add the script
	var enemy_script = preload("res://Enemies/Enemy.gd")
	enemy.set_script(enemy_script)
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.extents = Vector2(16, 16)
	collision.shape = shape
	enemy.add_child(collision)
	
	# Add sprite
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	var icon = preload("res://icon.svg")
	sprite.texture = icon
	sprite.scale = Vector2(0.5, 0.5)
	enemy.add_child(sprite)
	
	# Add health bar - FIXED VERSION
	var health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.size = Vector2(40, 5)
	health_bar.position = Vector2(-20, -30)
	health_bar.show_percentage = false
	
	# In Godot 4, we need to use Theme Overrides to set colors
	var theme = Theme.new()
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.2, 0.2, 0.2)  # Background color
	health_bar.add_theme_stylebox_override("fill", stylebox)  # Fill color
	
	# Or alternatively, use this simpler approach:
	health_bar.modulate = Color.WHITE  # The bar will use default theme
	
	enemy.add_child(health_bar)
	
	# Initialize
	enemy.initialize(wave_number)
	
	return enemy

func _on_enemy_died(worth):
	currency += worth  # This will trigger the setter and signal
	enemies_alive -= 1
	check_wave_complete()

func _on_enemy_reached_end():
	# Penalty for letting enemies through
	currency = max(0, currency - 10)  # This will trigger the setter
	enemies_alive -= 1
	check_wave_complete()

func check_wave_complete():
	if enemies_alive <= 0:
		wave_in_progress = false
		emit_signal("wave_completed")
		# Auto-start next wave after delay - using await
		await get_tree().create_timer(3.0).timeout
		start_wave()
