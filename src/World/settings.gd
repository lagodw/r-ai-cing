extends CanvasLayer

# Reference to the separate button scene we created
@onready var input_button_scene = preload("res://src/World/input_button.tscn")
@onready var action_list = %ActionList
@onready var music_slider = %MusicSlider
@onready var sfx_slider = %SfxSlider

# State variables for remapping
var is_remapping = false
var action_to_remap = null
var remapping_button = null

# Dictionary to map your internal Action Names to Display Names
# Make sure the keys (left side) match exactly what is in Project Settings > Input Map
var input_actions = {
	"move_up": "Forward",
	"drift": "Drift",
	"move_down": "Backward",
	"activate_slot_0": "Power 1",
	"move_right": "Steer Right",
	"activate_slot_1": "Power 2",
	"move_left": "Steer Left",
}

func _ready():
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	$Background/Close.pressed.connect(close)
	_create_action_list()
	
	# Connect the Reset button if it exists
	var reset_btn = find_child("ResetButton")
	if reset_btn:
		reset_btn.pressed.connect(_on_reset_pressed)

func _create_action_list():
	# Clear existing buttons
	for item in action_list.get_children():
		item.queue_free()
	
	# Create a button for each action in our dictionary
	for action in input_actions:
		var container = input_button_scene.instantiate()
		var button = container.get_node("Button")
		var action_label = container.get_node("%LabelAction")
		var input_label = container.get_node("%LabelInput")
		
		# Set the Display Name (e.g. "Forward")
		action_label.text = input_actions[action]
		
		# Get the current key assigned in Input Map
		var events = InputMap.action_get_events(action)
		if events.size() > 0:
			input_label.text = events[0].as_text().trim_suffix(" (Physical)")
		else:
			input_label.text = ""
		
		# Connect the button click to our remapping function
		button.pressed.connect(_on_input_button_pressed.bind(button, action))
		
		action_list.add_child(container)

func _on_input_button_pressed(button, action):
	if is_remapping: return
	
	is_remapping = true
	action_to_remap = action
	remapping_button = button
	
	# Visual feedback
	button.get_parent().get_node("%LabelInput").text = "Press key..."

func _input(event):
	if is_remapping:
		if (event is InputEventKey) or (event is InputEventMouseButton and event.pressed):
			
			# Prevent double-click issues
			if event is InputEventMouseButton and event.double_click:
				event.double_click = false
			
			# 1. Erase old events for this action
			InputMap.action_erase_events(action_to_remap)
			
			# 2. Add the new event
			InputMap.action_add_event(action_to_remap, event)
			
			# 3. Update the UI text
			_update_action_list(remapping_button, event)
			
			# Reset state
			is_remapping = false
			action_to_remap = null
			remapping_button = null
			
			# Stop the event from triggering other game logic immediately
			$Background.accept_event()

func _update_action_list(button, event):
	button.get_parent().get_node("%LabelInput").text = event.as_text().trim_suffix(" (Physical)")

func _on_reset_pressed():
	# Reloads the default Input Map from Project Settings
	InputMap.load_from_project_settings()
	_create_action_list()

func _on_master_volume_changed(value: float):
	AudioManager.set_bus_volume("Master", value)
	
func _on_music_volume_changed(value: float):
	AudioManager.set_bus_volume("Music", value)

func _on_sfx_volume_changed(value: float):
	AudioManager.set_bus_volume("SFX", value)

func close():
	visible = false
