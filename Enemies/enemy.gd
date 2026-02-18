# Scripts/enemy.gd
extends CharacterBody2D

signal enemy_died(worth)
signal enemy_reached_end

@export var speed: float = 100.0
@export var max_hp: int = 30
@export var worth: int = 25

var current_hp: int
var current_speed_mod = 1.0
var slow_stacks: int = 0    # How many slow towers are currently affecting this enemy
var path_follow: PathFollow2D
var is_initialized = false  # Track if we've been initialized
var is_dying = false         # Prevents movement and double-die calls

# Don't use @onready for health_bar since initialize is called before _ready
var sprite  # Can be Sprite2D or AnimatedSprite2D
var health_bar: ProgressBar
var health_label: Label  # Label to show health number

func initialize(wave_number):
	# Only set defaults if they haven't been overridden by child scenes
	if max_hp == 30:  # Still at the default export value
		max_hp = 10   # Base: regular enemy
	if speed == 100.0 and worth == 25:  # Still at defaults
		speed = 100
		worth = 10

	current_hp = max_hp
	is_initialized = true
	
	find_my_nodes()
	
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = max_hp

	if health_label:
		health_label.text = str(current_hp)

func find_my_nodes():
	# Find sprite
	sprite = get_node_or_null("AnimatedSprite2D")
	if not sprite:
		sprite = get_node_or_null("Sprite2D")
	if not sprite:
		print("Sprite not found")
	
	# Find and hide health bar
	health_bar = get_node_or_null("HealthBar")
	if not health_bar:
		health_bar = get_node_or_null("ProgressBar")
	if health_bar:
		health_bar.visible = false

	# Find health label
	health_label = get_node_or_null("HealthLabel")

func _ready():
	add_to_group("enemies")
	
	find_my_nodes()
	
	if sprite and sprite is AnimatedSprite2D:
		sprite.play("Walk")

	if is_initialized and health_bar:
		health_bar.max_value = max_hp
		health_bar.value = max_hp

func _process(delta):
	if not is_initialized or is_dying:
		return
	move_along_path(delta)

func move_along_path(delta):
	if not path_follow:
		return
	
	path_follow.progress += speed * current_speed_mod * delta
	
	if path_follow.progress >= path_follow.get_parent().curve.get_baked_length():
		reached_end()

func reached_end():
	emit_signal("enemy_reached_end")
	queue_free()

func take_damage(damage):
	if is_dying:
		return

	current_hp -= damage
	if health_bar:
		health_bar.value = current_hp
	if health_label:
		health_label.text = str(max(0, current_hp))
	
	if current_hp <= 0:
		die()

func die():
	if is_dying:
		return
	is_dying = true

	if sprite and sprite is AnimatedSprite2D:
		sprite.play("Death")
		await sprite.animation_finished

	emit_signal("enemy_died", worth)
	queue_free()

# ── Slow system (stack-based) ────────────────────────────────────────────────
# Each slow tower calls apply_slow() when the enemy enters its range,
# and remove_slow() when it exits. Stacks allow multiple towers to overlap.

func apply_slow(amount: float):
	slow_stacks += 1
	current_speed_mod = amount
	if sprite:
		sprite.modulate = Color(0.5, 0.7, 1.0)  # Blue tint while slowed

func remove_slow():
	slow_stacks = max(0, slow_stacks - 1)
	if slow_stacks == 0:
		current_speed_mod = 1.0
	if sprite:
			sprite.modulate = Color.WHITE  # Restore normal colour
