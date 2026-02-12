extends CanvasLayer

# Signal to tell the Track scene we are done
signal race_started

@onready var kart_option_scene = preload("res://src/World/kart_option.tscn")
@onready var projectile_option_scene = preload("res://src/World/projectile_option.tscn")

# State
var current_kart_node: Control = null
var current_power_nodes: Array[Control] = []
var temp_selected_kart_id: String = ""
var temp_selected_powers: Array[PowerDef] = []

func _ready() -> void:
	$KartSelection/ConfirmKart.pressed.connect(confirm_kart)
	$PowerSelection/ConfirmPower.pressed.connect(confirm_power)
	
	# --- 1. Load Random Karts ---
	var karts = GameData.karts.keys().duplicate()
	karts.shuffle()
	
	for i in range(min(3, karts.size())):
		var kart_id = karts[i]
		var option = kart_option_scene.instantiate()
		option.kart = GameData.karts[kart_id]
		option.selected.connect(_on_kart_selected)
		%Karts.add_child(option)

	# --- 2. Load Random Powers ---
	var powers = GameData.powers.keys().duplicate()
	powers.shuffle()
	
	for i in range(min(6, powers.size())):
		var power_id = powers[i]
		var power = GameData.powers[power_id]
		
		# Instantiate option for all types (projectiles, buffs, etc)
		var option = projectile_option_scene.instantiate()
		option.power = power
		option.selected.connect(_on_power_selected)
		%Powers.add_child(option)

# --- Kart Logic ---
func _on_kart_selected(kart_def, node):
	# Deselect previous
	if current_kart_node and current_kart_node != node:
		current_kart_node.set_highlight(false)
	
	# Select new
	current_kart_node = node
	current_kart_node.set_highlight(true)
	temp_selected_kart_id = kart_def.id

func confirm_kart():
	if temp_selected_kart_id == "": return # Must pick one
	
	$KartSelection.visible = false
	$PowerSelection.visible = true

# --- Power Logic ---
func _on_power_selected(power_def, node):
	if node in current_power_nodes:
		# Deselecting
		node.set_highlight(false)
		current_power_nodes.erase(node)
		temp_selected_powers.erase(power_def)
	else:
		# Selecting (Limit 2)
		if current_power_nodes.size() < 2:
			node.set_highlight(true)
			current_power_nodes.append(node)
			temp_selected_powers.append(power_def)

func confirm_power():
	# Ensure 2 are selected (or allow less if desired, here strict 2)
	if temp_selected_powers.size() != 2: 
		return 
		
	# Store in Global GameData
	GameData.selected_kart_id = temp_selected_kart_id
	GameData.selected_powers = temp_selected_powers.duplicate()
	
	race_started.emit()
	queue_free()
