# Scripts/game_manager.gd
extends Node2D

signal currency_changed(new_amount)
signal gems_changed(new_amount)
signal wave_completed
signal lives_changed(new_lives)
signal game_over
signal level_ready(level_num)        # Fires only at the START of a new level → shows Start button
signal level_loaded(level_node)      # Fires after the level scene has been swapped in

var currency: int = 300 :
	set(value):
		currency = value
		emit_signal("currency_changed", currency)

var gems: int = 3 :
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
var total_waves: int = 4          # Updated per level in _set_total_waves()
var enemies_alive: int = 0
var wave_in_progress: bool = false

# All Path2D nodes in the current level (populated by _find_paths)
var paths: Array = []
var path = null   # Keep for backward compatibility with older code

@onready var ui = $UI

func _ready():
	randomize()
	print("🎮 GameManager starting...")

	# Wire up the lose-screen transition
	game_over.connect(_on_game_over)

	var level = get_parent().get_node_or_null("Level1")
	if not level:
		push_error("Level1 not found!")
		return

	_find_paths(level)
	_set_total_waves(current_level)

	# One frame for UI to be ready, then show the level-start button
	await get_tree().process_frame
	emit_signal("level_ready", current_level)

# ── Lose-screen transition ───────────────────────────────────────────────────
func _on_game_over():
	print("💀 Game over — loading lose scene")
	wave_in_progress = false
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://Scenes/Levels/lose_scene.tscn")

# ── Called by UI when player presses Start Level button ─────────────────────
func start_wave_requested():
	start_wave()

# ── Called by UI when player presses Skip Intro Level ───────────────────────
func skip_to_next_level():
	print("⏭ Skipping Level 1 → Level 2")
	current_wave = 0
	wave_in_progress = false
	current_level = 2
	_set_total_waves(current_level)
	await _switch_to_level(current_level)
	_grant_level_start_resources(current_level)
	emit_signal("level_ready", current_level)

# ── Bonus resources granted at the start of each level (except Level 1) ──────
func _grant_level_start_resources(level: int):
	match level:
		2:
			currency += 500
			gems     += 20
			print("🎁 Level 2 bonus: +500 gold, +20 gems")
		3:
			currency += 400
			gems     += 15
			print("🎁 Level 3 bonus: +400 gold, +15 gems")
		_:
			# Level 4+: modest bonus that scales with level
			currency += 200 + level * 50
			gems     += 10
			print("🎁 Level %d bonus: +%d gold, +10 gems" % [level, 200 + level * 50])

# ── Wave logic ───────────────────────────────────────────────────────────────
func start_wave():
	if wave_in_progress:
		return
	wave_in_progress = true
	current_wave += 1
	spawn_wave(current_wave)

func spawn_wave(wave_number: int):
	var wave_label = "∞" if total_waves == 0 else str(total_waves)
	print("📦 Spawning Level %d Wave %d/%s" % [current_level, wave_number, wave_label])

	if paths.is_empty():
		push_error("No paths found!")
		return

	var wave_config  = get_wave_config(current_level, wave_number)
	var hp_mult      = _get_hp_multiplier(wave_number)
	enemies_alive    = wave_config.size()
	print("   Spawning %d enemies (HP ×%.0f): %s" % [enemies_alive, hp_mult, str(wave_config)])

	for i in range(wave_config.size()):
		var enemy = create_specific_enemy(wave_config[i], wave_number, hp_mult)
		if not enemy:
			push_error("Failed to create enemy!")
			continue

		enemy.enemy_died.connect(_on_enemy_died)
		enemy.enemy_reached_end.connect(_on_enemy_reached_end)
		enemy.loot_dropped.connect(_on_loot_dropped)

		var chosen_path = _get_spawn_path(wave_number, i)
		var pf = PathFollow2D.new()
		pf.name = "PathFollow_%d_%d" % [wave_number, i]
		pf.rotates = false
		pf.loop = false
		pf.add_child(enemy)
		chosen_path.add_child(pf)
		enemy.path_follow = pf
		pf.progress = 0

		print("   ✓ Spawned %s #%d on %s" % [wave_config[i], i + 1, chosen_path.name])

		var delay = _get_spawn_delay(wave_number)
		await get_tree().create_timer(delay).timeout

	print("Wave %d fully spawned!" % wave_number)

func _get_spawn_path(wave_number: int, enemy_index: int) -> Node:
	if paths.size() == 1:
		return paths[0]
	# Level 2: waves 1–2 → main path only; wave 3+ → alternate both paths
	if current_level == 2 and wave_number <= 2:
		return paths[0]
	# Level 3+: always alternate across all available paths
	return paths[enemy_index % paths.size()]

func _get_spawn_delay(wave_number: int) -> float:
	if current_level == 1 and wave_number == 2:
		return 0.2   # Wave 2: tight cluster
	if current_level == 2:
		return 0.30  # Level 2 faster pacing
	if current_level >= 3:
		return 0.22  # Level 3 (infinite) — fast pacing
	return 0.5

# ── Wave / level configs ──────────────────────────────────────────────────────
# total_waves == 0 means the level is infinite (Level 3+)
func _set_total_waves(level: int):
	match level:
		1: total_waves = 4
		2: total_waves = 10
		_: total_waves = 0   # 0 = infinite

func get_wave_config(level: int, wave: int) -> Array:
	match level:
		1: return _l1_wave(wave)
		2: return _l2_wave(wave)
		_: return _l3_wave(wave)   # Level 3+ — infinite procedural waves

func _l1_wave(wave: int) -> Array:
	# Tutorial — small quantities, one type per wave to teach the player
	match wave:
		1: return ["regular","regular","regular"]
		2: return ["regular","regular","regular","regular","regular","regular","regular","regular"]
		3: return ["fast","fast","fast"]
		4: return ["tank","tank"]
		_: return ["regular"]

func _l2_wave(wave: int) -> Array:
	# Waves 1–2: single path   Waves 3–10: both paths
	# Difficulty = QUANTITY. HP scales gently (+12%/wave) so gold income scales with it.
	match wave:
		# ×1.00 HP
		1:  return ["regular","regular","regular","fast","regular","regular","regular","fast","regular","regular","regular","regular"]
		2:  return ["regular","fast","fast","regular","regular","fast","fast","regular","regular","fast","regular","regular","regular"]
		# ×1.12 HP
		3:  return ["fast","fast","fast","regular","regular","regular","fast","fast","regular","fast","fast","regular","regular","fast"]
		4:  return ["fast","fast","fast","fast","tank","regular","regular","fast","fast","regular","fast","fast","fast","tank","regular"]
		# ×1.25 HP
		5:  return ["tank","fast","fast","fast","fast","regular","tank","fast","fast","tank","fast","fast","fast","regular","regular"]
		6:  return ["tank","tank","fast","fast","fast","fast","regular","tank","fast","fast","fast","tank","tank","fast","fast","fast"]
		# ×1.40 HP
		7:  return ["tank","tank","fast","fast","fast","fast","fast","fast","tank","tank","fast","tank","fast","fast","fast","fast","fast"]
		8:  return ["tank","tank","tank","fast","fast","fast","fast","fast","regular","tank","tank","fast","fast","tank","fast","fast","fast","fast"]
		# ×1.57 HP
		9:  return ["tank","tank","tank","fast","fast","fast","fast","fast","fast","tank","tank","tank","fast","fast","fast","fast","fast","fast","fast"]
		10: return ["tank","tank","tank","tank","fast","fast","fast","fast","fast","fast","tank","tank","tank","fast","fast","fast","fast","fast","fast","fast","tank","fast"]
		_:  return ["tank","tank","fast","fast","regular"]

# ── Level 3: infinite procedural waves ───────────────────────────────────────
# Enemy count grows fast so gold income keeps up with rising HP.
func _l3_wave(wave: int) -> Array:
	var enemies: Array = []
	# Tanks: start at 3, +2 every 2 waves, cap at 20
	var n_tanks   = min(3 + (wave - 1), 20)
	# Fast:  start at 6, +3 per wave, cap at 30
	var n_fast    = min(6 + (wave - 1) * 3, 30)
	# Regular: present for first 6 waves only
	var n_regular = max(0, 6 - wave)

	for _i in n_tanks:   enemies.append("tank")
	for _i in n_fast:    enemies.append("fast")
	for _i in n_regular: enemies.append("regular")
	return enemies

# ── HP scaling: +12% per wave for Level 2, +10% per wave for Level 3+ ────────
# Gentler than before — challenge comes from QUANTITY, not HP walls.
# Level 2  wave 5 ≈ ×1.6×   wave 10 ≈ ×2.8×
# Level 3  wave 10 ≈ ×2.4×  wave 20 ≈ ×6.1×
func _get_hp_multiplier(wave_number: int) -> float:
	if current_level < 2:
		return 1.0
	var growth_rate = 1.12 if current_level == 2 else 1.10
	return pow(growth_rate, wave_number - 1)

# ── Loot drop textures (preloaded once) ──────────────────────────────────────
var gold_texture: Texture2D = preload("res://Sprites/SimpleFantasyResourceIcons/Gold.png")
var gem_texture:  Texture2D = preload("res://Sprites/SimpleFantasyResourceIcons/Item 4-1.png.png")

# ── Enemy factories ───────────────────────────────────────────────────────────
var regular_enemy_scene = preload("res://Enemies/Enemy.tscn")
var fast_enemy_scene    = preload("res://Enemies/FastEnemy.tscn")
var tank_enemy_scene    = preload("res://Enemies/TankEnemy.tscn")

func create_specific_enemy(enemy_type: String, wave_number: int, hp_mult: float = 1.0):
	var enemy
	match enemy_type:
		"regular": enemy = regular_enemy_scene.instantiate()
		"fast":    enemy = fast_enemy_scene.instantiate()
		"tank":    enemy = tank_enemy_scene.instantiate()
		_:
			push_error("Unknown enemy type: " + enemy_type)
			enemy = regular_enemy_scene.instantiate()
	enemy.initialize(wave_number)

	# Apply HP multiplier (doubles every 2 waves on Level 2+)
	if hp_mult > 1.0:
		enemy.max_hp    = int(ceil(float(enemy.max_hp) * hp_mult))
		enemy.current_hp = enemy.max_hp
		var lbl = enemy.get_node_or_null("HealthLabel")
		if lbl:
			lbl.text = str(enemy.max_hp)

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

func _on_loot_dropped(world_pos: Vector2, gold: int, gem_count: int):
	# Add gems to player resources
	if gem_count > 0:
		gems += gem_count

	# Show gold indicator above death position
	_spawn_float_label(world_pos + Vector2(0, -24), "+%d" % gold, gold_texture, Color(1.0, 0.85, 0.1, 1.0))

	# Show gem indicator slightly above the gold one (if any gems dropped)
	if gem_count > 0:
		_spawn_float_label(world_pos + Vector2(0, -48), "+%d" % gem_count, gem_texture, Color(0.4, 0.9, 1.0, 1.0))

func _spawn_float_label(world_pos: Vector2, text: String, icon: Texture2D, color: Color):
	var main = get_parent()

	# Container: HBoxContainer with icon + label
	var hbox = HBoxContainer.new()
	hbox.position = world_pos

	var tex_rect = TextureRect.new()
	tex_rect.texture = icon
	tex_rect.custom_minimum_size = Vector2(18, 18)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_font_size_override("font_size", 16)

	hbox.add_child(tex_rect)
	hbox.add_child(lbl)
	main.add_child(hbox)

	# Tween: float up 50 px and fade out over 1.4 s
	var tween = hbox.create_tween()
	tween.set_parallel(true)
	tween.tween_property(hbox, "position", world_pos + Vector2(0, -60), 1.4)
	tween.tween_property(hbox, "modulate:a", 0.0, 1.4)
	await tween.finished
	hbox.queue_free()

func check_wave_complete():
	if enemies_alive > 0:
		return

	wave_in_progress = false
	emit_signal("wave_completed")

	# Infinite level (total_waves == 0) — never advance, just keep going
	if total_waves == 0:
		await get_tree().create_timer(3.0).timeout
		start_wave()
		return

	if current_wave >= total_waves:
		# ── All waves in this level done — advance
		print("✅ Level %d complete!" % current_level)
		await get_tree().create_timer(2.0).timeout
		current_level += 1
		current_wave = 0
		_set_total_waves(current_level)
		await _switch_to_level(current_level)
		_grant_level_start_resources(current_level)
		emit_signal("level_ready", current_level)
	else:
		# ── Auto-start next wave after a short breather
		await get_tree().create_timer(3.0).timeout
		start_wave()

# ── Level switching ───────────────────────────────────────────────────────────
func _find_paths(level_node: Node):
	paths.clear()
	path = null

	# Primary path is always named "Path2D"
	var p1 = level_node.get_node_or_null("Path2D")
	if p1:
		paths.append(p1)
		path = p1

	# Secondary path in level 2 is named "Path2"
	var p2 = level_node.get_node_or_null("Path2")
	if p2:
		paths.append(p2)

	print("Found %d path(s) in %s" % [paths.size(), level_node.name])

func _switch_to_level(level_num: int):
	var main = get_parent()

	# Remove old level node(s)
	for child in main.get_children():
		if child.name.begins_with("Level"):
			child.queue_free()
	await get_tree().process_frame

	var level_path = "res://Scenes/Levels/level_%d.tscn" % level_num
	if not ResourceLoader.exists(level_path):
		push_error("Level scene not found: " + level_path)
		return

	var level_instance = load(level_path).instantiate()
	level_instance.name = "Level%d" % level_num
	main.add_child(level_instance)
	# Keep it behind the GameManager in z-order
	main.move_child(level_instance, 1)

	await get_tree().process_frame
	_find_paths(level_instance)
	emit_signal("level_loaded", level_instance)
