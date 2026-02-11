class_name Kart extends CharacterBody2D

# --- Configuration & Resources ---
@export var kart_id: String = "speedster" # Default ID, overwritten by Spawner
@export var is_player_controlled: bool = false
@export var auto_gas: bool = false # Set true for simple mobile mode

# The Resource containing base stats (Loaded from JSON)
var stats: KartDef 

# --- Dynamic Stats (Copied from Resource for runtime modification) ---
var max_speed: float = 500.0
var acceleration: float = 800.0
var turn_speed: float = 3.5
var friction: float = 0.95
var max_health: int = 100
var current_health: int = 100

# --- State Variables ---
var current_speed: float = 0.0
var is_stunned: bool = false
var power_inventory: Array = [null, null, null] # Slots 0, 1, 2

# --- Input Interface (Decoupled for AI/Multiplayer) ---
var input_steer: float = 0.0    # -1.0 (Left) to 1.0 (Right)
var input_throttle: float = 0.0 # -1.0 (Brake) to 1.0 (Gas)

# --- Node References ---
@onready var sprite = $Sprite2D
@onready var collider = $CollisionShape2D

func _enter_tree():
	# Try to parse the name as a Player ID
	var id_from_name = name.to_int()
	
	if id_from_name > 0:
		# It's a valid Player ID (e.g. "1", "2491")
		set_multiplayer_authority(id_from_name)
	else:
		# It's a Bot (e.g. "Bot_1") or invalid.
		# Default to Server Authority (1) so the host runs the physics.
		set_multiplayer_authority(1)

func _ready():
	# Load the stats defined in JSON via the GameData factory
	configure_from_id(kart_id)

# --- Setup ---
func configure_from_id(id: String):
	stats = GameData.karts.get(id)
	
	if not stats:
		printerr("Kart ID not found: ", id)
		return

	# Apply Visuals
	if ResourceLoader.exists(stats.sprite_path):
		sprite.texture = load(stats.sprite_path)
	
	# Copy Stats so we can modify them (e.g. buffs) without changing the Resource
	max_speed = stats.max_speed
	acceleration = stats.acceleration
	turn_speed = stats.turn_speed
	max_health = stats.max_health
	current_health = max_health

# --- Main Loop ---
func _physics_process(delta):
	# 1. Multiplayer Check: Only the owner controls the physics
	if not is_multiplayer_authority():
		return 
		# The MultiplayerSynchronizer node handles position updates for non-owners

	# 2. Status Check
	if is_stunned:
		_handle_stunned_physics(delta)
		return

	# 3. Logic
	_gather_input()
	_apply_physics(delta)

# --- Physics & Movement ---
func _gather_input():
	if is_player_controlled:
		# PC / Console Input
		var move_axis = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		input_steer = move_axis.x
		input_throttle = -move_axis.y # Up is negative Y, but positive throttle
		
		# Mobile Overrides (If Virtual Joystick is active)
		# Assumes a global or easy way to access the joystick, or input actions mapped to buttons
		if auto_gas and input_throttle == 0:
			input_throttle = 1.0 # Always drive forward unless braking
			
		# Ability Inputs
		if Input.is_action_just_pressed("activate_slot_0"): use_power(0)
		if Input.is_action_just_pressed("activate_slot_1"): use_power(1)
		if Input.is_action_just_pressed("activate_slot_2"): use_power(2)
		
	else:
		# AI Input is handled by the AIController child node
		# effectively writing to 'input_steer' and 'input_throttle' variables
		pass

func _apply_physics(delta):
	# A. Steering
	if input_steer != 0 and current_speed != 0:
		# Reverse steering if going backward? (Optional realism)
		var dir = 1 if current_speed > 0 else -1
		rotation += input_steer * turn_speed * delta * dir

	# B. Acceleration
	var target_speed = 0.0
	
	if input_throttle > 0:
		target_speed = max_speed
	elif input_throttle < 0:
		target_speed = -max_speed * 0.5 # Reverse is slower
	
	# C. Friction / Engine Power
	if input_throttle != 0:
		current_speed = move_toward(current_speed, target_speed, acceleration * delta)
	else:
		# Coasting
		current_speed = move_toward(current_speed, 0, friction * 500 * delta)

	# D. Move
	velocity = transform.x * current_speed
	move_and_slide()

func _handle_stunned_physics(delta):
	# Spin out or slide to a stop
	current_speed = move_toward(current_speed, 0, friction * 200 * delta)
	velocity = transform.x * current_speed
	sprite.rotation_degrees += 720 * delta # Spin effect
	move_and_slide()

# --- Combat & Health ---
func take_damage(amount: int):
	if is_stunned: return # Can't kill what's already dead
	
	current_health -= amount
	
	# RPC: Tell everyone I took damage (for visual effects/sounds)
	rpc("on_damaged_visual", current_health)
	
	if current_health <= 0:
		_break_down()

func _break_down():
	is_stunned = true
	current_health = 0
	
	# Drop all items?
	# power_inventory = [null, null, null]
	
	print(name + " has broken down!")
	
	# Respawn Timer
	await get_tree().create_timer(3.0).timeout
	_respawn()

func _respawn():
	is_stunned = false
	current_health = max_health
	sprite.rotation = 0 # Reset spin
	
	# Invincibility frames
	sprite.modulate.a = 0.5
	await get_tree().create_timer(2.0).timeout
	sprite.modulate.a = 1.0

# --- Abilities ---
func use_power(slot_index: int):
	# Check Bounds
	if slot_index < 0 or slot_index >= power_inventory.size(): return
	
	var power_id = power_inventory[slot_index]
	if power_id == null: return
	
	# Multiplayer: Execute on all clients
	rpc("activate_power_effect", power_id)
	
	# Consume item (Optional)
	# power_inventory[slot_index] = null 

@rpc("call_local")
func activate_power_effect(power_id: String):
	# Calls the global manager to spawn projectiles/hazards
	PowerManager.activate_power(self, power_id)

@rpc("call_local")
func on_damaged_visual(_new_health):
	# Flash Red
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
