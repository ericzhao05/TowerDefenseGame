# Scripts/tower_slow.gd
# Slow tower: draws a transparent blue range circle.
# Enemies that walk inside the circle are slowed to half speed.
# Their speed is restored the moment they leave the circle.
# Shows a white level number above the flag pole.
extends Area2D

@export var tower_name: String = "Slow Tower"
@export var cost: int = 75
@export var range_radius: float = 75.0
@export var slow_amount: float = 0.5  # 0.5 = half speed

var level: int = 1
var is_ghost: bool = false
var slowed_enemies: Array = []  # Enemies currently inside the circle

@onready var range_shape: CollisionShape2D = $Range
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	if is_ghost:
		return

	# Size the collision circle to the exported radius
	if range_shape and range_shape.shape:
		range_shape.shape.radius = range_radius

	# Connect Area2D signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Show level label above the top of the flag
	# Flag frame: 32x64, sprite offset -32 → top of sprite at -32-32 = -64
	var level_label = get_node_or_null("TowerLevel")
	if level_label:
		level_label.visible = true
		level_label.text = str(level)
		level_label.position = Vector2(-16, -72)

	# Trigger the _draw() call to paint the range circle
	queue_redraw()

	if sprite:
		sprite.play("Attack")

func _draw():
	if is_ghost:
		return
	# Filled transparent blue circle
	draw_circle(Vector2.ZERO, range_radius, Color(0.2, 0.5, 1.0, 0.12))
	# Solid blue border ring
	draw_arc(Vector2.ZERO, range_radius, 0.0, TAU, 64, Color(0.3, 0.6, 1.0, 0.7), 2.0)

func _process(_delta):
	# Remove enemies that died while inside the circle
	for enemy in slowed_enemies.duplicate():
		if not is_instance_valid(enemy):
			slowed_enemies.erase(enemy)

# ── Area2D callbacks ─────────────────────────────────────────────────────────
func _on_body_entered(body: Node2D):
	if body.is_in_group("enemies") and not slowed_enemies.has(body):
		slowed_enemies.append(body)
		if body.has_method("apply_slow"):
			body.apply_slow(slow_amount)

func _on_body_exited(body: Node2D):
	if slowed_enemies.has(body):
		slowed_enemies.erase(body)
		if is_instance_valid(body) and body.has_method("remove_slow"):
			body.remove_slow()

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
			slow_amount = 0.35   # Slower to 35% speed
			range_radius = 90.0
		3:
			slow_amount = 0.2    # Slower to 20% speed
			range_radius = 110.0
	if range_shape and range_shape.shape:
		range_shape.shape.radius = range_radius
