# UI/game_ui.gd
extends CanvasLayer

@onready var currency_label = $TopBar/CurrencyLabel
@onready var gems_label     = $TopBar/GemsLabel
@onready var wave_label     = $TopBar/WaveLabel
@onready var lives_label    = $TopBar/LivesLabel
@onready var tower_shop     = $TowerShop
@onready var start_button   = $StartButton
@onready var skip_button    = $SkipButton

# References
var game_manager = null
var grid_manager = null
var pending_purchase_button = null

func _ready():
	game_manager = get_parent()   # UI's parent is GameManager

	# Initial GridManager lookup (Level 1)
	_connect_grid_manager(get_node_or_null("/root/Main/Level1"))

	if game_manager:
		game_manager.currency_changed.connect(_on_currency_changed)
		game_manager.gems_changed.connect(_on_gems_changed)
		game_manager.wave_completed.connect(_on_wave_completed)
		game_manager.lives_changed.connect(_on_lives_changed)
		game_manager.level_ready.connect(_on_level_ready)
		game_manager.level_loaded.connect(_on_level_loaded)

		_on_currency_changed(game_manager.currency)
		_on_gems_changed(game_manager.gems)
		_on_lives_changed(game_manager.lives)
		update_wave_display()
		print("GameManager found")
	else:
		print("ERROR: GameManager not found in game_ui.gd")

	if tower_shop:
		tower_shop.purchase_tower.connect(_on_purchase_tower)

	# Buttons start hidden; level_ready signal will reveal them
	if start_button:
		start_button.visible = false
		start_button.pressed.connect(_on_start_pressed)

	if skip_button:
		skip_button.visible = false
		skip_button.pressed.connect(_on_skip_pressed)

# ── Level-start button ────────────────────────────────────────────────────────
func _on_level_ready(level_num: int):
	if start_button:
		if level_num >= 3:
			start_button.text = "▶  Start Level %d  — ∞ Survive!" % level_num
		else:
			start_button.text = "▶  Start Level %d" % level_num
		start_button.visible = true

	# Skip button only on Level 1
	if skip_button:
		skip_button.visible = (level_num == 1)

	# Auto-refresh the shop at the start of every new level (after Level 1)
	if level_num > 1 and tower_shop and tower_shop.has_method("generate_shop"):
		tower_shop.generate_shop()

	update_wave_display()

func _on_start_pressed():
	if start_button: start_button.visible = false
	if skip_button:  skip_button.visible = false
	if game_manager:
		game_manager.start_wave_requested()

func _on_skip_pressed():
	if start_button: start_button.visible = false
	if skip_button:  skip_button.visible = false
	if game_manager:
		game_manager.skip_to_next_level()

# ── Level scene changed ───────────────────────────────────────────────────────
func _on_level_loaded(level_node: Node):
	_connect_grid_manager(level_node)

func _connect_grid_manager(level_node: Node):
	if not level_node:
		return
	grid_manager = level_node.get_node_or_null("GridManager")
	if grid_manager:
		if not grid_manager.tower_placed.is_connected(_on_tower_placed):
			grid_manager.tower_placed.connect(_on_tower_placed)
		print("GridManager found in " + level_node.name)
	else:
		print("WARNING: GridManager not found in " + level_node.name)

# ── Shop ──────────────────────────────────────────────────────────────────────
func _on_purchase_tower(tower_type: String, slot: Button):
	if grid_manager:
		pending_purchase_button = slot
		grid_manager.start_drag(tower_type)
	else:
		print("ERROR: Cannot purchase tower, GridManager not found!")

func _on_tower_placed(_tower_type, _grid_pos):
	if pending_purchase_button and tower_shop:
		tower_shop.remove_tower_slot(pending_purchase_button)
		pending_purchase_button = null

# ── Stat displays ─────────────────────────────────────────────────────────────
func _on_currency_changed(new_amount):
	if currency_label:
		currency_label.text = str(new_amount)

func _on_gems_changed(new_amount):
	if gems_label:
		gems_label.text = str(new_amount)

func _on_lives_changed(new_lives):
	if lives_label:
		lives_label.text = str(new_lives)
		if new_lives <= 5:
			lives_label.modulate = Color.RED
		elif new_lives <= 10:
			lives_label.modulate = Color.YELLOW
		else:
			lives_label.modulate = Color.WHITE

func _on_wave_completed():
	if game_manager:
		update_wave_display()
		if wave_label:
			var lvl  = game_manager.current_level
			var wave = game_manager.current_wave
			if game_manager.total_waves == 0:
				wave_label.text = "Level %d - Wave %d Cleared!" % [lvl, wave]
			else:
				wave_label.text = "Level %d - Wave: %d/%d Done!" % [lvl, wave, game_manager.total_waves]
			wave_label.modulate = Color.YELLOW
			await get_tree().create_timer(1.0).timeout
			wave_label.modulate = Color.WHITE
			update_wave_display()

func update_wave_display():
	if wave_label and game_manager:
		var lvl  = game_manager.current_level
		var wave = game_manager.current_wave
		if wave == 0:
			wave_label.text = "Level %d - Ready" % lvl
		elif game_manager.total_waves == 0:
			# Infinite level — no max wave number shown
			wave_label.text = "Level %d - Wave: %d" % [lvl, wave]
		else:
			wave_label.text = "Level %d - Wave: %d/%d" % [lvl, wave, game_manager.total_waves]
