# Scripts/lose_scene.gd
# Displayed when the player runs out of lives.
# All UI lives inside a CanvasLayer so it correctly fills the viewport
# regardless of the Node2D camera/world transform.
extends Node2D

func _ready():
	# ── CanvasLayer keeps UI in screen-space ──────────────────────────────────
	var canvas = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	# ── Full-screen dark background ───────────────────────────────────────────
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.0, 0.0, 1.0)   # Deep dark-red, fully opaque
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	# ── "YOU LOSE" title ─────────────────────────────────────────────────────
	var title = Label.new()
	title.text = "YOU LOSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	title.add_theme_constant_override("outline_size", 6)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top    = 140.0
	title.offset_left   = -240.0
	title.offset_right  =  240.0
	title.offset_bottom =  220.0
	canvas.add_child(title)

	# ── Flavour subtitle ──────────────────────────────────────────────────────
	var sub = Label.new()
	sub.text = "The kingdom has fallen…"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(0.9, 0.65, 0.45, 1.0))
	sub.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	sub.add_theme_constant_override("outline_size", 3)
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.offset_top    = 230.0
	sub.offset_left   = -200.0
	sub.offset_right  =  200.0
	sub.offset_bottom =  270.0
	canvas.add_child(sub)

	# ── Restart button ────────────────────────────────────────────────────────
	var btn = Button.new()
	btn.text = "▶  Try Again"
	btn.add_theme_font_size_override("font_size", 22)
	btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	btn.offset_top    = 300.0
	btn.offset_left   = -110.0
	btn.offset_right  =  110.0
	btn.offset_bottom =  355.0
	btn.pressed.connect(_on_restart_pressed)
	canvas.add_child(btn)

func _on_restart_pressed():
	get_tree().change_scene_to_file("res://Scenes/Game.tscn")
