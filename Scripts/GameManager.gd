# Scripts/game_manager.gd
extends Node2D

signal currency_changed(new_amount)
signal gems_changed(new_amount)
signal wave_completed
signal lives_changed(new_lives)
signal game_over
signal wave_ready(level_num, wave_num, total_waves)   # Shown to player before each wave

var currency: int = 300 :
	set(value):
		currency = value
		emit_signal("currency_changed", currency)

var gems: int = 10 :
	set(value):
		gems = value
		emit_signal("gems_changed", gems)

var lives: int = 20 :
	set(value):
		lives = value
		emit_signal("lives_changed", lives)
		if lives <= 0:
			emit_signal("game_over")

var current_level: int = 1
var current_wave: int = 0
var total_waves: int = 4          # Waves per level
var enemies_alive: int = 0
var wave_in_progress: bool = false

var path
@onready var ui = $UI

func _ready():
	randomize()
	print("🎮 GameManager starting...")

	var level = get_parent().get_node_or_null("Level1")
	if level:
		path = level.get_node_or_null("Path2D")
		print("Found Level1 and Path2D")
	else:
		push_error("ERROR: Level1 not found!")
		return

	# Wait a frame for UI to be ready, then show the Start button
	await get_tree().process_frame
	_notify_wave_ready()

# ── Called by UI when the player presses the Start button ───────────────────
func start_wave_requested():
	start_wave()

func start_wave():
	if wave_in_progress:
		return
	wave_in_progress = true
	current_wave += 1
	spawn_wave(current_wave)

# ── Wave spawning ─────────────────────────────────────────────────────────────
func spawn_wave(wave_number: int):
	print("📦 Spawning Level %d Wave %d" % [current_level, wave_number])

	if not path:
		push_error("Path not found!")
		return
	if not path.curve or path.curve.get_point_count() == 0:
		push_error("Path has no points!")
		return

	var wave_config = get_wave_config(current_level, wave_number)
	enemies_alive = wave_config.size()
	print("   Spawning", enemies_alive, "enemies:", wave_config)

	for i in range(wave_config.size()):
		var enemy_type = wave_config[i]
		var enemy = create_specific_enemy(enemy_type, wave_number)
		if not enemy:
			push_error("Failed to create enemy!")
			continue

		enemy.enemy_died.connect(_on_enemy_died)
		enemy.enemy_reached_end.connect(_on_enemy_reached_end)

		var path_follow = PathFollow2D.new()
		path_follow.name = "PathFollow_" + str(i)
		path_follow.rotates = false
		path_follow.loop = false
		path_follow.add_child(enemy)
		path.add_child(path_follow)
		enemy.path_follow = path_follow
		path_follow.progress = 0

		print("   ✓ Spawned", enemy_type, "enemy", i + 1, "/", enemies_alive)

		var spawn_delay = 0.5
		if current_level == 1 and wave_number == 2:
			spawn_delay = 0.2   # Wave 2: tight cluster
		await get_tree().create_timer(spawn_delay).timeout

	print("Level %d Wave %d fully spawned!" % [current_level, wave_number])

# ── Wave / level configs ──────────────────────────────────────────────────────
func get_wave_config(level: int, wave: int) -> Array:
	match level:
		1: return get_level1_wave_config(wave)
		2: return get_level2_wave_config(wave)
		_: return get_level2_wave_config(wave)  # Level 2+ pattern continues

func get_level1_wave_config(wave: int) -> Array:
	match wave:
		1: return ["regular", "regular"]
		2: return ["regular", "regular", "regular", "regular", "regular"]
		3: return ["fast"]
		4: return ["tank"]
		_: return ["regular"]

func get_level2_wave_config(wave: int) -> Array:
	match wave:
		1: return ["regular", "regular", "fast"]
		2: return ["fast", "fast", "regular", "regular"]
		3: return ["tank", "fast", "fast"]
		4: return ["tank", "tank", "fast", "fast", "regular"]
		_: return ["tank", "fast", "regular"]

# ── Enemy factories ───────────────────────────────────────────────────────────
var regular_enemy_scene = preload("res://Enemies/Enemy.tscn")
var fast_enemy_scene    = preload("res://Enemies/FastEnemy.tscn")
var tank_enemy_scene    = preload("res://Enemies/TankEnemy.tscn")

func create_specific_enemy(enemy_type: String, wave_number: int):
	var enemy
	match enemy_type:
		"regular": enemy = regular_enemy_scene.instantiate()
		"fast":    enemy = fast_enemy_scene.instantiate()
		"tank":    enemy = tank_enemy_scene.instantiate()
		_:
			push_error("Unknown enemy type: " + enemy_type)
			enemy = regular_enemy_scene.instantiate()
	enemy.initialize(wave_number)
	return enemy

# ── Enemy event handlers ──────────────────────────────────────────────────────
func _on_enemy_died(worth):
	currency += worth
	enemies_alive -= 1
	check_wave_complete()

func _on_enemy_reached_end():
	lives -= 1
	enemies_alive -= 1
	check_wave_complete()

func check_wave_complete():
	if enemies_alive > 0:
		return

	wave_in_progress = false
	emit_signal("wave_completed")

	if current_wave >= total_waves:
		# ── All waves in this level done — advance to next level
		print("✅ Level %d complete!" % current_level)
		await get_tree().create_timer(2.0).timeout
		current_level += 1
		current_wave = 0
		print("➡️  Starting Level %d..." % current_level)
		_notify_wave_ready()
	else:
		# ── More waves remain — show Start button again
		await get_tree().create_timer(1.5).timeout
		_notify_wave_ready()

func _notify_wave_ready():
	emit_signal("wave_ready", current_level, current_wave + 1, total_waves)
