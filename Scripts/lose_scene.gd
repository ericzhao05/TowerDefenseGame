# Scripts/lose_scene.gd
# Displayed when the player runs out of lives.
extends Node2D

func _ready():
	# ── Dark overlay ──────────────────────────────────────────────────────────
	var overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# ── "YOU LOSE" title ─────────────────────────────────────────────────────
	var title = Label.new()
	title.text = "YOU LOSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	title.add_theme_constant_override("outline_size", 6)
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-240, -120)
	title.size = Vector2(480, 90)
	add_child(title)

	# ── Sub-message ───────────────────────────────────────────────────────────
	var sub = Label.new()
	sub.text = "The kingdom has fallen…"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(0.9, 0.7, 0.5, 1.0))
	sub.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	sub.add_theme_constant_override("outline_size", 3)
	sub.set_anchors_preset(Control.PRESET_CENTER)
	sub.position = Vector2(-200, -20)
	sub.size = Vector2(400, 40)
	add_child(sub)

	# ── Restart button ────────────────────────────────────────────────────────
	var btn = Button.new()
	btn.text = "▶  Try Again"
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0.1, 0.05, 0.0, 1.0))
	btn.set_anchors_preset(Control.PRESET_CENTER)
	btn.position = Vector2(-100, 60)
	btn.size = Vector2(200, 50)
	btn.pressed.connect(_on_restart_pressed)
	add_child(btn)

func _on_restart_pressed():
	get_tree().change_scene_to_file("res://Scenes/Game.tscn")
