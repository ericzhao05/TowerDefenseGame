# UI/tower_slot.gd
# Individual tower display slot in the shop
extends Button

signal tower_slot_clicked(tower_type: String, cost: int)

var tower_type: String = ""
var tower_cost: int = 0
var tower_name_text: String = ""
var tower_scene_path: String = ""
var sprite_loaded: bool = false

func _ready():
	pressed.connect(_on_pressed)
	
	# Load sprite if setup was called before _ready
	if not sprite_loaded and tower_scene_path != "":
		_load_tower_sprite()
	
func setup(t_type: String, cost: int, t_name: String):
	tower_type = t_type
	tower_cost = cost
	tower_name_text = t_name
	tower_scene_path = "res://Towers/" + tower_type + ".tscn"
	
	# Update labels immediately
	await get_tree().process_frame  # Wait for nodes to be ready
	
	var name_label = get_node_or_null("VBoxContainer/NameLabel")
	var cost_label = get_node_or_null("VBoxContainer/CostLabel")
	
	if name_label:
		name_label.text = t_name
	if cost_label:
		cost_label.text = "$" + str(cost)
	
	# Load tower sprite
	_load_tower_sprite()

func _load_tower_sprite():
	if sprite_loaded:
		return
		
	if not ResourceLoader.exists(tower_scene_path):
		print("Tower scene not found:", tower_scene_path)
		return
	
	var sprite_container = get_node_or_null("VBoxContainer/SpriteContainer")
	if not sprite_container:
		print("Sprite container not found!")
		return
	
	var tower_scene = load(tower_scene_path)
	var tower_instance = tower_scene.instantiate()
	
	# Find AnimatedSprite2D in the tower
	var animated_sprite = tower_instance.get_node_or_null("AnimatedSprite2D")
	if animated_sprite:
		# Create a preview sprite
		var preview_sprite = AnimatedSprite2D.new()
		preview_sprite.sprite_frames = animated_sprite.sprite_frames
		preview_sprite.animation = animated_sprite.animation
		preview_sprite.scale = Vector2(1.8, 1.8)  # Scale for preview
		preview_sprite.position = Vector2(100, 0)  # Shift sprite right (increase x to move more right)
		preview_sprite.play()
		sprite_container.add_child(preview_sprite)
		sprite_loaded = true
		print("Loaded sprite for:", tower_type)
	else:
		print("AnimatedSprite2D not found in tower:", tower_type)
	
	# Clean up the temporary instance
	tower_instance.queue_free()

func _on_pressed():
	emit_signal("tower_slot_clicked", tower_type, tower_cost)

