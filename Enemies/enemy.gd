# Scripts/enemy.gd
extends CharacterBody2D

signal enemy_died(worth)
signal enemy_reached_end

@export var speed: float = 100.0
@export var max_hp: int = 30
@export var worth: int = 25

var current_hp: int
var current_speed_mod = 1.0
var slow_timer = 0.0
var path_follow: PathFollow2D
var is_initialized = false  # Track if we've been initialized

# Don't use @onready for health_bar since initialize is called before _ready
var sprite: Sprite2D
var health_bar: ProgressBar
var slow_timer_node: Timer

func initialize(wave_number):
	# Store the wave data
	max_hp = 30 + (wave_number * 10)
	speed = 100 + (wave_number * 10)
	worth = 25 + (wave_number * 5)
	current_hp = max_hp
	is_initialized = true
	
	# Try to find nodes now
	find_my_nodes()
	
	# Update health bar if it exists
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = max_hp
	else:
		print("Warning: Health bar not found yet, will try again in _ready")

func find_my_nodes():
	# Find sprite
	sprite = get_node_or_null("Sprite2D")
	if not sprite:
		print("Sprite2D not found")
	
	# Find health bar - try multiple possible names
	health_bar = get_node_or_null("HealthBar")
	if not health_bar:
		health_bar = get_node_or_null("ProgressBar")
	if not health_bar:
		health_bar = get_node_or_null("health_bar")
	
	# Find timer
	slow_timer_node = get_node_or_null("Timer")
	
	# If health bar still not found, create it
	if not health_bar:
		create_health_bar()

func create_health_bar():
	print("Creating health bar dynamically")
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.size = Vector2(40, 5)
	health_bar.position = Vector2(-20, -30)
	health_bar.show_percentage = false
	health_bar.tint_progress = Color.RED
	add_child(health_bar)
	
	if is_initialized:
		health_bar.max_value = max_hp
		health_bar.value = max_hp

func _ready():
	add_to_group("enemies")
	
	# Find nodes (in case they weren't found in initialize)
	find_my_nodes()
	
	# If we were initialized before _ready, update health bar now
	if is_initialized and health_bar:
		health_bar.max_value = max_hp
		health_bar.value = max_hp
	
	# Connect timer if it exists
	if slow_timer_node:
		slow_timer_node.timeout.connect(_on_slow_timer_timeout)

func _process(delta):
	if not is_initialized:
		return
	
	if slow_timer > 0:
		slow_timer -= delta
	else:
		current_speed_mod = 1.0
		if sprite:
			sprite.modulate = Color.WHITE
	
	move_along_path(delta)

func move_along_path(delta):
	if not path_follow:
		return
	
	path_follow.progress += speed * current_speed_mod * delta
	
	# Check if reached end
	if path_follow.progress >= path_follow.get_parent().curve.get_baked_length():
		reached_end()

func reached_end():
	emit_signal("enemy_reached_end")
	queue_free()

func take_damage(damage):
	current_hp -= damage
	if health_bar:
		health_bar.value = current_hp
	
	if current_hp <= 0:
		die()

func die():
	emit_signal("enemy_died", worth)
	queue_free()

func apply_slow(amount, duration):
	current_speed_mod = amount
	slow_timer = duration
	# Visual feedback for slow
	if sprite:
		sprite.modulate = Color(0.5, 0.5, 1.0)
	
	if slow_timer_node:
		slow_timer_node.start(duration)

func _on_slow_timer_timeout():
	if sprite:
		sprite.modulate = Color.WHITE
