# Scripts/enemy.gd
extends CharacterBody2D

signal enemy_died(worth)
signal enemy_reached_end
signal loot_dropped(world_pos, gold, gems)   # Fired just before the enemy is freed

@export var speed: float = 100.0
@export var max_hp: int = 30
@export var worth: int = 25

# Gold drop range (overridden per enemy type in their .tscn)
# Regular enemy defaults: 8–12 gold
@export var min_gold_drop: int = 20   # Regular enemy default: 20–25
@export var max_gold_drop: int = 25

var current_hp: int
var current_speed_mod = 1.0
var slow_stacks: int = 0
var path_follow: PathFollow2D
var is_initialized = false
var is_dying = false

var sprite
var health_bar: ProgressBar
var health_label: Label

func initialize(wave_number):
	# Only set defaults if they haven't been overridden by child scenes
	if max_hp == 30:
		max_hp = 10
	if speed == 100.0 and worth == 25:
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
	sprite = get_node_or_null("AnimatedSprite2D")
	if not sprite:
		sprite = get_node_or_null("Sprite2D")

	health_bar = get_node_or_null("HealthBar")
	if not health_bar:
		health_bar = get_node_or_null("ProgressBar")
	if health_bar:
		health_bar.visible = false

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

	# Play death animation first
	if sprite and sprite is AnimatedSprite2D:
		sprite.play("Death")
		await sprite.animation_finished

	# ── Calculate loot ──────────────────────────────────────────────────────
	var gold_drop = randi_range(min_gold_drop, max_gold_drop)
	var gem_drop  = 0
	if randf() < 0.20:           # 20 % chance
		gem_drop = randi_range(2, 8)

	# Emit loot signal with world position (before queue_free!)
	emit_signal("loot_dropped", global_position, gold_drop, gem_drop)

	# worth is now driven by the randomised gold drop so GameManager stays correct
	emit_signal("enemy_died", gold_drop)
	queue_free()

# ── Slow system ───────────────────────────────────────────────────────────────
func apply_slow(amount: float):
	slow_stacks += 1
	current_speed_mod = amount
	if sprite:
		sprite.modulate = Color(0.5, 0.7, 1.0)

func remove_slow():
	slow_stacks = max(0, slow_stacks - 1)
	if slow_stacks == 0:
		current_speed_mod = 1.0
	if sprite:
		sprite.modulate = Color.WHITE
