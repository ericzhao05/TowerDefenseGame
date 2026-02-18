# Scripts/grid_manager.gd
extends Node2D

signal tower_placed(tower_type, grid_pos)
signal tower_selected(tower)

const GRID_SIZE   = 32
const GRID_WIDTH  = 40
const GRID_HEIGHT = 32

# placed_towers: cell_key (String) → { "tower": Node2D, "type": String }
var placed_towers: Dictionary = {}

# ── Shop-drag state ────────────────────────────────────────────────────────────
var current_drag_tower = null
var drag_tower_type: String = ""
var drag_active: bool = false
var merge_mode: bool = false      # True when a same-type tower already exists on the field

# ── Click-to-merge state ───────────────────────────────────────────────────────
var tower_selected_mode: bool = false
var selected_tower_cell: Vector2i = Vector2i(-9999, -9999)
var selected_tower_type: String = ""

var grid_overlay: Node2D = null

@onready var game_manager = get_node("/root/Main/GameManager")
@onready var tilemap: TileMap = get_parent().get_node_or_null("Map")

func _ready():
	grid_overlay = Node2D.new()
	grid_overlay.name = "GridOverlay"
	grid_overlay.z_index = 100
	grid_overlay.visible = false
	add_child(grid_overlay)
	print("GridManager ready")

func _process(_delta):
	if drag_active and current_drag_tower:
		update_drag_position(get_global_mouse_position())
		grid_overlay.queue_redraw()
	elif tower_selected_mode:
		grid_overlay.queue_redraw()

# ──────────────────────────────────────────────────────────────────────────────
#  DRAG FROM SHOP
# ──────────────────────────────────────────────────────────────────────────────

func start_drag(tower_type: String):
	var tower_cost = get_tower_cost(tower_type)
	if game_manager and game_manager.currency < tower_cost:
		print("Not enough money! Need $%d, have $%d" % [tower_cost, game_manager.currency])
		return

	if drag_active:
		stop_drag()

	drag_tower_type = tower_type
	drag_active = true

	# Merge mode: does the field already contain a SAME-TYPE, LEVEL-1 tower?
	# (Shop towers always start at level 1, so only level-1 field towers can be merged.)
	merge_mode = false
	for key in placed_towers:
		var td = placed_towers[key]
		if td["type"] == tower_type and _get_tower_level(td["tower"]) == 1:
			merge_mode = true
			break

	if merge_mode:
		_highlight_towers_for_merge(tower_type, 1)  # level 1 = shop drag always

	# Ghost tower (transparent preview that follows the cursor)
	var tower_path = "res://Towers/" + tower_type + ".tscn"
	current_drag_tower = load(tower_path).instantiate()
	current_drag_tower.modulate = Color(1, 1, 1, 0.6)
	current_drag_tower.process_mode = PROCESS_MODE_DISABLED
	var ghost_label = current_drag_tower.get_node_or_null("TowerLevel")
	if ghost_label:
		ghost_label.visible = false

	add_child(current_drag_tower)
	grid_overlay.visible = true
	_setup_grid_overlay_drawing()
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	print("Started dragging: %s  merge_mode=%s" % [tower_type, str(merge_mode)])

# Returns the current level of a tower node (defaults to 1 if the property doesn't exist)
func _get_tower_level(tower_node) -> int:
	if is_instance_valid(tower_node) and "level" in tower_node:
		return tower_node.level
	return 1

func _setup_grid_overlay_drawing():
	if not grid_overlay.draw.is_connected(_draw_grid):
		grid_overlay.draw.connect(_draw_grid)

func _draw_grid():
	# Active during shop-drag OR click-to-merge
	if not tilemap:
		return
	if not drag_active and not tower_selected_mode:
		return

	var hover_tile  = tilemap.local_to_map(get_global_mouse_position())
	var layer_count = tilemap.get_layers_count()

	# Collect every unique cell position that has a tile on ANY layer
	var all_cells: Dictionary = {}
	for layer in range(layer_count):
		for cell in tilemap.get_used_cells(layer):
			all_cells[cell] = true

	# Pre-compute selected tower level for click-to-merge mode
	var sel_level: int = 1
	if tower_selected_mode:
		var sel_ck = _cell_key(selected_tower_cell)
		if placed_towers.has(sel_ck):
			sel_level = _get_tower_level(placed_towers[sel_ck]["tower"])

	for cell_pos in all_cells:
		var world_pos = tilemap.map_to_local(cell_pos)
		var occupied  = is_cell_occupied(cell_pos)
		var buildable = check_tile_buildable(cell_pos)
		var rect_pos  = world_pos - Vector2(GRID_SIZE / 2.0, GRID_SIZE / 2.0)
		var rect      = Rect2(rect_pos, Vector2(GRID_SIZE, GRID_SIZE))

		# ── SHOP DRAG MODE ────────────────────────────────────────────────────────
		if drag_active:
			if cell_pos == hover_tile:
				var hover_color = Color.WHITE if buildable and not occupied else Color.RED
				if merge_mode and occupied:
					var ck = _cell_key(cell_pos)
					if placed_towers.has(ck) and _is_valid_merge_target(placed_towers[ck], drag_tower_type, 1):
						hover_color = Color.GREEN
				grid_overlay.draw_rect(rect, Color(hover_color.r, hover_color.g, hover_color.b, 0.55))
				grid_overlay.draw_rect(rect, Color(hover_color.r, hover_color.g, hover_color.b, 0.85), false, 2.0)
				continue

			if occupied:
				var ck = _cell_key(cell_pos)
				if merge_mode and placed_towers.has(ck) and _is_valid_merge_target(placed_towers[ck], drag_tower_type, 1):
					grid_overlay.draw_rect(rect, Color(0.3, 1.0, 0.3, 0.20))
					grid_overlay.draw_rect(rect, Color(0.3, 1.0, 0.3, 0.60), false, 1.5)
				else:
					grid_overlay.draw_rect(rect, Color(1.0, 0.2, 0.2, 0.25))
					grid_overlay.draw_rect(rect, Color(1.0, 0.2, 0.2, 0.60), false, 1.5)
			elif not buildable:
				grid_overlay.draw_rect(rect, Color(1.0, 0.2, 0.2, 0.28))
				grid_overlay.draw_rect(rect, Color(1.0, 0.2, 0.2, 0.55), false, 1.5)
			# Empty buildable: draw nothing

		# ── CLICK-TO-MERGE MODE ───────────────────────────────────────────────────
		elif tower_selected_mode:
			# Selected tower's own tile — bright cyan so it stands out
			if cell_pos == selected_tower_cell:
				grid_overlay.draw_rect(rect, Color(0.2, 0.9, 1.0, 0.40))
				grid_overlay.draw_rect(rect, Color(0.2, 0.9, 1.0, 0.95), false, 2.5)
				continue

			if occupied:
				var ck = _cell_key(cell_pos)
				if placed_towers.has(ck) and _is_valid_merge_target(placed_towers[ck], selected_tower_type, sel_level):
					# Valid merge target — green
					if cell_pos == hover_tile:
						grid_overlay.draw_rect(rect, Color(0.3, 1.0, 0.3, 0.55))
						grid_overlay.draw_rect(rect, Color(0.3, 1.0, 0.3, 0.90), false, 2.0)
					else:
						grid_overlay.draw_rect(rect, Color(0.3, 1.0, 0.3, 0.22))
						grid_overlay.draw_rect(rect, Color(0.3, 1.0, 0.3, 0.65), false, 1.5)
				else:
					# Incompatible tower — red (brighter on hover)
					if cell_pos == hover_tile:
						grid_overlay.draw_rect(rect, Color(1.0, 0.2, 0.2, 0.55))
						grid_overlay.draw_rect(rect, Color(1.0, 0.2, 0.2, 0.90), false, 2.0)
					else:
						grid_overlay.draw_rect(rect, Color(1.0, 0.2, 0.2, 0.22))
						grid_overlay.draw_rect(rect, Color(1.0, 0.2, 0.2, 0.55), false, 1.5)
			elif not buildable:
				grid_overlay.draw_rect(rect, Color(1.0, 0.2, 0.2, 0.28))
				grid_overlay.draw_rect(rect, Color(1.0, 0.2, 0.2, 0.55), false, 1.5)
			# Empty buildable: draw nothing

func update_drag_position(world_pos: Vector2):
	if not current_drag_tower:
		return

	current_drag_tower.position = snap_to_grid(world_pos)

	var tile_pos  = tilemap.local_to_map(world_pos)
	var occupied  = is_cell_occupied(tile_pos)
	var buildable = check_tile_buildable(tile_pos)

	if occupied:
		var ck = _cell_key(tile_pos)
		if merge_mode and placed_towers.has(ck) and _is_valid_merge_target(placed_towers[ck], drag_tower_type, 1):
			current_drag_tower.modulate = Color(0.3, 1.0, 0.3, 0.6)  # Green  = valid merge
		else:
			current_drag_tower.modulate = Color(1.0, 0.3, 0.3, 0.6)  # Red    = blocked
	elif not buildable:
		current_drag_tower.modulate = Color(1.0, 0.3, 0.3, 0.6)      # Red    = not buildable
	else:
		current_drag_tower.modulate = Color(0.3, 1.0, 0.3, 0.6)      # Green  = valid place

func stop_drag():
	_clear_tower_highlights()
	merge_mode = false

	if current_drag_tower:
		current_drag_tower.queue_free()
		current_drag_tower = null

	drag_tower_type = ""
	drag_active = false

	if grid_overlay:
		grid_overlay.visible = false

	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

# ──────────────────────────────────────────────────────────────────────────────
#  PLACEMENT
# ──────────────────────────────────────────────────────────────────────────────

func place_tower(tower_type: String, tile_pos: Vector2i) -> bool:
	print("=== PLACE TOWER: %s at %s ===" % [tower_type, str(tile_pos)])

	if not check_tile_buildable(tile_pos):
		print("FAIL: Tile not buildable")
		return false

	if is_cell_occupied(tile_pos):
		print("FAIL: Cell occupied")
		return false

	var tower_cost = get_tower_cost(tower_type)
	if game_manager and game_manager.currency < tower_cost:
		print("FAIL: Not enough money")
		return false

	var tower_path = "res://Towers/" + tower_type + ".tscn"
	if not ResourceLoader.exists(tower_path):
		print("FAIL: Scene not found:", tower_path)
		return false

	var tower = load(tower_path).instantiate()
	if not tower:
		print("FAIL: Could not instantiate")
		return false

	tower.position = tilemap.map_to_local(tile_pos)
	# Note: _ready() in each tower script shows TowerLevel; do NOT hide it here.
	add_child(tower)

	var ck = _cell_key(tile_pos)
	placed_towers[ck] = {"tower": tower, "type": tower_type}

	if game_manager:
		game_manager.currency -= tower_cost

	emit_signal("tower_placed", tower_type, tile_pos)
	print("SUCCESS: %s placed at %s" % [tower_type, str(tile_pos)])
	return true

# ──────────────────────────────────────────────────────────────────────────────
#  MERGE — shop drag → field tower
# ──────────────────────────────────────────────────────────────────────────────

func _merge_shop_into_field(tile_pos: Vector2i):
	# The player is buying a new tower from the shop and merging it directly into
	# an existing same-type field tower.
	var tower_cost = get_tower_cost(drag_tower_type)
	if game_manager and game_manager.currency < tower_cost:
		print("Not enough money to merge!")
		return

	if game_manager:
		game_manager.currency -= tower_cost

	var ck    = _cell_key(tile_pos)
	var tower = placed_towers[ck]["tower"]
	if is_instance_valid(tower) and tower.has_method("upgrade"):
		tower.upgrade()
		_show_level_up_popup(tower.global_position)
		print("Shop-merge at", tile_pos)

# ──────────────────────────────────────────────────────────────────────────────
#  MERGE — field tower → field tower (click-to-merge)
# ──────────────────────────────────────────────────────────────────────────────

func _merge_field_into_field(source_pos: Vector2i, target_pos: Vector2i):
	var sk = _cell_key(source_pos)
	var tk = _cell_key(target_pos)

	# Free the source tower
	var src_tower = placed_towers[sk]["tower"]
	if is_instance_valid(src_tower):
		src_tower.queue_free()
	placed_towers.erase(sk)

	# Upgrade the target tower
	var tgt_tower = placed_towers[tk]["tower"]
	if is_instance_valid(tgt_tower) and tgt_tower.has_method("upgrade"):
		tgt_tower.upgrade()
		_show_level_up_popup(tgt_tower.global_position)
		print("Field-merge %s → %s" % [str(source_pos), str(target_pos)])

# ──────────────────────────────────────────────────────────────────────────────
#  TOWER CLICK-TO-SELECT / MERGE
# ──────────────────────────────────────────────────────────────────────────────

func _select_tower(tile_pos: Vector2i):
	var ck        = _cell_key(tile_pos)
	var td        = placed_towers[ck]
	var sel_type  = td["type"]
	var sel_level = _get_tower_level(td["tower"])

	# Count compatible towers: SAME TYPE and SAME LEVEL required
	var targets: int = 0
	for key in placed_towers:
		if key != ck and _is_valid_merge_target(placed_towers[key], sel_type, sel_level):
			targets += 1

	if targets == 0:
		# Nothing to merge with — give a quick red flash and bail
		if is_instance_valid(td["tower"]):
			td["tower"].modulate = Color(1.0, 0.4, 0.4, 1.0)
			await get_tree().create_timer(0.4).timeout
			if is_instance_valid(td["tower"]):
				td["tower"].modulate = Color.WHITE
		return

	selected_tower_cell = tile_pos
	selected_tower_type = sel_type
	tower_selected_mode = true

	_highlight_towers_for_merge(sel_type, sel_level)
	# The selected tower itself gets a brighter highlight to show it is "held"
	if is_instance_valid(td["tower"]):
		td["tower"].modulate = Color(0.1, 1.4, 0.1, 1.0)

	# Show the grid overlay so the player can see compatible tiles
	grid_overlay.visible = true
	_setup_grid_overlay_drawing()

func _deselect_tower():
	_clear_tower_highlights()
	tower_selected_mode = false
	selected_tower_cell = Vector2i(-9999, -9999)
	selected_tower_type = ""
	if not drag_active:
		grid_overlay.visible = false

# ──────────────────────────────────────────────────────────────────────────────
#  HIGHLIGHT HELPERS
# ──────────────────────────────────────────────────────────────────────────────

# Returns true when `td` (a placed_towers entry) is a valid merge partner:
# must be same type AND same level.
func _is_valid_merge_target(td: Dictionary, target_type: String, target_level: int) -> bool:
	if not is_instance_valid(td["tower"]):
		return false
	return td["type"] == target_type and _get_tower_level(td["tower"]) == target_level

func _highlight_towers_for_merge(reference_type: String, reference_level: int):
	for key in placed_towers:
		var td = placed_towers[key]
		if not is_instance_valid(td["tower"]):
			continue
		if _is_valid_merge_target(td, reference_type, reference_level):
			td["tower"].modulate = Color(0.4, 1.0, 0.4, 1.0)   # Green — same type & level
		else:
			td["tower"].modulate = Color(1.0, 0.4, 0.4, 1.0)   # Red   — different type or level

func _clear_tower_highlights():
	for key in placed_towers:
		var td = placed_towers[key]
		if is_instance_valid(td["tower"]):
			td["tower"].modulate = Color.WHITE

# ──────────────────────────────────────────────────────────────────────────────
#  LEVEL-UP POPUP
# ──────────────────────────────────────────────────────────────────────────────

func _show_level_up_popup(world_pos: Vector2):
	var lbl = Label.new()
	lbl.text = "Level +"
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.position = world_pos + Vector2(-30, -90)

	var main = get_node("/root/Main")
	main.add_child(lbl)

	var tween = lbl.create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position", lbl.position + Vector2(0, -55), 1.5)
	tween.tween_property(lbl, "modulate:a", 0.0, 1.5)
	await tween.finished
	lbl.queue_free()

# ──────────────────────────────────────────────────────────────────────────────
#  INPUT
# ──────────────────────────────────────────────────────────────────────────────

func _input(event):
	# Keyboard cancel
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if drag_active: stop_drag()
			elif tower_selected_mode: _deselect_tower()
		return

	if not (event is InputEventMouseButton and event.pressed):
		return

	var mb = event as InputEventMouseButton

	# Right-click always cancels
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		if drag_active: stop_drag()
		elif tower_selected_mode: _deselect_tower()
		return

	if mb.button_index != MOUSE_BUTTON_LEFT:
		return

	var mouse_pos = get_global_mouse_position()
	var tile_pos  = tilemap.local_to_map(mouse_pos)

	# ── SHOP DRAG ──────────────────────────────────────────────────────────────
	if drag_active:
		if merge_mode and is_cell_occupied(tile_pos):
			var ck = _cell_key(tile_pos)
			if placed_towers.has(ck) and _is_valid_merge_target(placed_towers[ck], drag_tower_type, 1):
				# Drop on a same-type, same-level (1) tower → merge and consume the shop slot
				_merge_shop_into_field(tile_pos)
				stop_drag()
				# Tell the UI to remove the slot (reuse the tower_placed signal path)
				emit_signal("tower_placed", drag_tower_type, tile_pos)
				return

		# Regular placement
		if place_tower(drag_tower_type, tile_pos):
			stop_drag()
		return

	# ── CLICK-TO-MERGE MODE ────────────────────────────────────────────────────
	if tower_selected_mode:
		if is_cell_occupied(tile_pos):
			var ck  = _cell_key(tile_pos)
			var sel_ck = _cell_key(selected_tower_cell)

			if tile_pos == selected_tower_cell:
				_deselect_tower()                              # Clicked same tower → cancel
			elif placed_towers.has(ck) and placed_towers.has(sel_ck) and \
				 _is_valid_merge_target(placed_towers[ck], selected_tower_type,
									   _get_tower_level(placed_towers[sel_ck]["tower"])):
				# Same type AND same level → merge
				_merge_field_into_field(selected_tower_cell, tile_pos)
				_deselect_tower()
			else:
				_deselect_tower()                              # Different type or level → cancel
		else:
			_deselect_tower()                                  # Clicked empty → cancel
		return

	# ── IDLE — click an occupied tile to enter select mode ────────────────────
	if is_cell_occupied(tile_pos):
		_select_tower(tile_pos)

# ──────────────────────────────────────────────────────────────────────────────
#  GRID / TILE HELPERS
# ──────────────────────────────────────────────────────────────────────────────

func check_tile_buildable(tile_pos: Vector2i) -> bool:
	if not tilemap:
		return false

	# Layer 0 must have a floor tile — otherwise it's outside the map
	if not tilemap.get_cell_tile_data(0, tile_pos):
		return false

	# Check EVERY layer: if any layer at this position has a blocking flag,
	# the tile is not buildable.
	# Layer 0 = floor / path   (tagged is_path)
	# Layer 1 = stones / deco  (tagged is_not_buildable)
	# Layer 2 = trees           (tagged is_not_buildable)
	for layer in range(tilemap.get_layers_count()):
		var tile_data = tilemap.get_cell_tile_data(layer, tile_pos)
		if not tile_data:
			continue   # No tile on this layer at this position — skip
		if tile_data.get_custom_data("is_not_buildable"):
			return false
		if tile_data.get_custom_data("is_path"):
			return false

	return true   # No blocking flags found on any layer → buildable

func is_cell_occupied(tile_pos: Vector2i) -> bool:
	return placed_towers.has(_cell_key(tile_pos))

func snap_to_grid(pos: Vector2) -> Vector2:
	if not tilemap:
		return pos
	return tilemap.map_to_local(tilemap.local_to_map(pos))

func get_grid_pos(pos: Vector2) -> Vector2i:
	if not tilemap:
		return Vector2i.ZERO
	return tilemap.local_to_map(pos)

func get_tower_cost(tower_type: String) -> int:
	match tower_type:
		"TowerBase": return 50
		"SlowTower": return 75
		"aoe_tower": return 100
		_:           return 50

func _cell_key(tile_pos: Vector2i) -> String:
	return "%d,%d" % [tile_pos.x, tile_pos.y]
