# UI/game_ui.gd
extends CanvasLayer

@onready var currency_label = $TopBar/CurrencyLabel
@onready var gems_label     = $TopBar/GemsLabel
@onready var wave_label     = $TopBar/WaveLabel
@onready var lives_label    = $TopBar/LivesLabel
@onready var tower_shop     = $TowerShop
@onready var start_button   = $StartButton

# References
var game_manager = null
var grid_manager = null
var pending_purchase_button = null

func _ready():
	game_manager = get_parent()   # UI's parent is GameManager

	var level = get_node("/root/Main/Level1")
	if level:
		grid_manager = level.get_node_or_null("GridManager")

	if game_manager:
		game_manager.currency_changed.connect(_on_currency_changed)
		game_manager.gems_changed.connect(_on_gems_changed)
		game_manager.wave_completed.connect(_on_wave_completed)
		game_manager.lives_changed.connect(_on_lives_changed)
		game_manager.wave_ready.connect(_on_wave_ready)

		_on_currency_changed(game_manager.currency)
		_on_gems_changed(game_manager.gems)
		_on_lives_changed(game_manager.lives)
		update_wave_display()
		print("GameManager found")
	else:
		print("ERROR: GameManager not found in game_ui.gd")

	if grid_manager:
		grid_manager.tower_placed.connect(_on_tower_placed)
		print("GridManager found")
	else:
		print("WARNING: GridManager not found in game_ui.gd")

	if tower_shop:
		tower_shop.purchase_tower.connect(_on_purchase_tower)

	# Start button starts hidden — GameManager will show it via wave_ready signal
	if start_button:
		start_button.visible = false
		start_button.pressed.connect(_on_start_pressed)

# ── Start button ──────────────────────────────────────────────────────────────
func _on_wave_ready(level_num: int, wave_num: int, total_waves: int):
	if start_button:
		start_button.text = "▶  Start Wave %d/%d" % [wave_num, total_waves]
		start_button.visible = true
	update_wave_display()

func _on_start_pressed():
	if start_button:
		start_button.visible = false
	if game_manager:
		game_manager.start_wave_requested()

# ── Shop ──────────────────────────────────────────────────────────────────────
func _on_purchase_tower(tower_type: String, slot: Button):
	if grid_manager:
		pending_purchase_button = slot
		grid_manager.start_drag(tower_type)
	else:
		print("ERROR: Cannot purchase tower, GridManager not found!")

func _on_tower_placed(tower_type, _grid_pos):
	if pending_purchase_button and tower_shop:
		tower_shop.remove_tower_slot(pending_purchase_button)
		pending_purchase_button = null

# ── Stat displays ─────────────────────────────────────────────────────────────
func _on_currency_changed(new_amount):
	if currency_label:
		currency_label.text = ": $" + str(new_amount)

func _on_gems_changed(new_amount):
	if gems_label:
		gems_label.text = ": " + str(new_amount)

func _on_lives_changed(new_lives):
	if lives_label:
		lives_label.text = "Lives: " + str(new_lives)
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
			wave_label.text = "Wave %d Complete!" % game_manager.current_wave
			wave_label.modulate = Color.YELLOW
			await get_tree().create_timer(1.0).timeout
			wave_label.modulate = Color.WHITE
			update_wave_display()

func update_wave_display():
	if wave_label and game_manager:
		wave_label.text = "Level %d  Wave %d/%d" % [
			game_manager.current_level,
			game_manager.current_wave,
			game_manager.total_waves
		]
