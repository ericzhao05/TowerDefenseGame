# Scripts/tower_base.gd
# Single-target tower: rectangular attack zone in front of it.
# Draws a red rectangle. Shows level number above head.
extends Area2D

signal tower_clicked(tower)

@export var tower_name: String = "Base Tower"
@export var cost: int = 50
@export var range_radius: float = 80.0   # Forward reach of the rectangle
@export var range_height: float = 50.0   # Vertical height of the rectangle
@export var attack_cooldown: float = 1.0
@export var base_damage: int = 10

var level: int = 1
var is_ghost: bool = false
var facing_right: bool = true            # Tracks which way the tower is facing
var current_target = null
var enemies_in_range: Array = []
var attack_sfx: AudioStreamPlayer = null

@onready var range_shape: CollisionShape2D = $Range
@onready var attack_timer: Timer = $Attacktimer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	if is_ghost:
		return

	# ── Attack SFX ────────────────────────────────────────────────────────────
	attack_sfx = AudioStreamPlayer.new()
	attack_sfx.stream = load("res://Music/BaseTower/Sword.mp3")
	attack_sfx.volume_db = -6.0
	add_child(attack_sfx)

	# Shape is a RectangleShape2D — resize it to match the exported range values
	if range_shape and range_shape.shape is RectangleShape2D:
		range_shape.shape.size = Vector2(range_radius, range_height)
		range_shape.position = Vector2(range_radius / 2.0, 0)  # Push it to the right

	# Repeating attack timer
	if attack_timer:
		attack_timer.wait_time = attack_cooldown
		attack_timer.one_shot = false
		attack_timer.timeout.connect(_on_attack_timer_timeout)
		attack_timer.start()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Level label just above the king's head (sprite offset -50, half-height ~55)
	var level_label = get_node_or_null("TowerLevel")
	if level_label:
		level_label.visible = true
		level_label.text = str(level)
		level_label.position = Vector2(-16, -70)

	queue_redraw()

	if sprite:
		sprite.play("Idle")

# ── Red rectangle range visualiser ──────────────────────────────────────────
func _draw():
	if is_ghost:
		return
	var x_start = 0.0 if facing_right else -range_radius
	var fill_color = Color(1.0, 0.2, 0.2, 0.10)
	var border_color = Color(1.0, 0.2, 0.2, 0.70)
	draw_rect(Rect2(x_start, -range_height / 2.0, range_radius, range_height), fill_color)
	draw_rect(Rect2(x_start, -range_height / 2.0, range_radius, range_height), border_color, false, 2.0)

func _process(_delta):
	if is_ghost:
		return

	enemies_in_range = enemies_in_range.filter(func(e): return is_instance_valid(e) and not e.is_dying)
	current_target = enemies_in_range[0] if enemies_in_range.size() > 0 else null

	if current_target and is_instance_valid(current_target):
		_face_target(current_target)
		if sprite and sprite.animation != "Attack":
			sprite.play("Attack")
	else:
		if sprite and sprite.animation != "Idle":
			sprite.play("Idle")

# ── Facing — also moves the rectangle to the correct side ───────────────────
func _face_target(target: Node2D):
	if not sprite:
		return
	var was_facing_right = facing_right
	sprite.flip_h = target.global_position.x < global_position.x
	facing_right = not sprite.flip_h

	if facing_right != was_facing_right:
		# Slide the collision rectangle to the side the tower now faces
		if range_shape:
			range_shape.position.x = (range_radius / 2.0) if facing_right else -(range_radius / 2.0)
		queue_redraw()  # Redraw the visual rectangle on the correct side

# ── Attacking ────────────────────────────────────────────────────────────────
func _on_attack_timer_timeout():
	if current_target and is_instance_valid(current_target):
		current_target.take_damage(base_damage)
		if attack_sfx and not attack_sfx.playing:
			attack_sfx.play()

# ── Area2D callbacks ─────────────────────────────────────────────────────────
func _on_body_entered(body: Node2D):
	if body.is_in_group("enemies") and not enemies_in_range.has(body):
		enemies_in_range.append(body)

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
	# Each level: +5 flat damage
	base_damage += 5
	# Refresh collision shape dimensions (range stays the same, no size increase)
	if range_shape and range_shape.shape is RectangleShape2D:
		range_shape.shape.size = Vector2(range_radius, range_height)
		range_shape.position.x = (range_radius / 2.0) if facing_right else -(range_radius / 2.0)
