# Scripts/tower_aoe.gd
# AOE tower: on each timer tick, damages ALL enemies inside its range.
# Draws a purple range circle. Shows level number above head.
extends Area2D

@export var tower_name: String = "AOE Tower"
@export var cost: int = 125
@export var range_radius: float = 100.0
@export var attack_cooldown: float = 2.5   # Longer cooldown, hits everything at once
@export var base_damage: int = 8

var level: int = 1
var is_ghost: bool = false
var enemies_in_range: Array = []

@onready var range_shape: CollisionShape2D = $Range
@onready var attack_timer: Timer = $Attacktimer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	if is_ghost:
		return

	# Size the range circle
	if range_shape and range_shape.shape:
		range_shape.shape.radius = range_radius

	# Repeating attack timer
	if attack_timer:
		attack_timer.wait_time = attack_cooldown
		attack_timer.one_shot = false
		attack_timer.timeout.connect(_on_attack_timer_timeout)
		attack_timer.start()

	# Detect enemies
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Show level label above head
	# Wizard frame: 231x190, sprite offset -80 → head at -80-95 = -175
	var level_label = get_node_or_null("TowerLevel")
	if level_label:
		level_label.visible = true
		level_label.text = str(level)
		level_label.position = Vector2(-16, -70)

	# Draw the purple range circle
	queue_redraw()

	if sprite:
		sprite.play("Idle")

# ── Range circle (purple) ────────────────────────────────────────────────────
func _draw():
	if is_ghost:
		return
	draw_circle(Vector2.ZERO, range_radius, Color(0.6, 0.1, 0.9, 0.10))
	draw_arc(Vector2.ZERO, range_radius, 0.0, TAU, 64, Color(0.7, 0.2, 1.0, 0.70), 2.0)

func _process(_delta):
	if is_ghost:
		return

	# Drop dead/dying enemies
	enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e) and not e.is_dying)

	# Switch animation based on whether enemies are nearby
	if enemies_in_range.size() > 0:
		if sprite and sprite.animation != "Attack":
			sprite.play("Attack")
	else:
		if sprite and sprite.animation != "Idle":
			sprite.play("Idle")

# ── Attack — hits every enemy in range ──────────────────────────────────────
func _on_attack_timer_timeout():
	for enemy in enemies_in_range.duplicate():
		if is_instance_valid(enemy) and not enemy.is_dying:
			enemy.take_damage(base_damage)

# ── Area2D callbacks ─────────────────────────────────────────────────────────
func _on_body_entered(body: Node2D):
	if body.is_in_group("enemies") and not enemies_in_range.has(body):
		enemies_in_range.append(body)
		# Hit the entering enemy immediately so damage feels instant,
		# then reset the timer so the next burst is a full cooldown away.
		if not body.is_dying:
			body.take_damage(base_damage)
		if attack_timer:
			attack_timer.start()  # Restart the cooldown from now

func _on_body_exited(body: Node2D):
	enemies_in_range.erase(body)

# ── Upgrades ─────────────────────────────────────────────────────────────────
func upgrade():
	level += 1
	_apply_upgrade_stats()
	var level_label = get_node_or_null("TowerLevel")
	if level_label:
		level_label.text = str(level)
	queue_redraw()

func _apply_upgrade_stats():
	match level:
		2:
			base_damage = 12
			range_radius = 120.0
		3:
			base_damage = 18
			range_radius = 140.0
	if range_shape and range_shape.shape:
		range_shape.shape.radius = range_radius
