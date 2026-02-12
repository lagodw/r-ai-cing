class_name Kart extends CharacterBody2D

signal lap_finished(lap_num)
signal race_finished(winner_name)
signal cooldown_started(slot_index: int, duration: float)

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
var current_health: int = 100:
	set(val):
		current_health = val
		update_health_bar()

# --- State Variables ---
var current_speed: float = 0.0
var is_stunned: bool = false
var power_inventory: Array[PowerDef] = [null, null, null] # Slots 0, 1, 2
var slot_on_cooldown: Array[bool] = [false, false, false]
var current_lap: int = 0
var last_waypoint_index: int = -1
var laps_finished: bool = false
var current_waypoint_index: int = 0
var wp_threshold: float = 200.0 # Increased threshold for wider roads

var weight: float = 1.0
var bump_velocity: Vector2 = Vector2.ZERO
var bump_decay: float = 800.0 # How fast the bump force fades
var last_bump_time: float = 0.0
var bump_cooldown: float = 0.5 # Seconds before you can bump again

# --- Input Interface (Decoupled for AI/Multiplayer) ---
var input_steer: float = 0.0    # -1.0 (Left) to 1.0 (Right)
var input_throttle: float = 0.0 # -1.0 (Brake) to 1.0 (Gas)

# --- Node References ---
@onready var sprite = $Sprite2D
@onready var collider = $CollisionShape2D
@onready var health_bar = $HealthBarAnchor/ProgressBar
@onready var health_anchor = $HealthBarAnchor

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
	
	add_to_group("karts")
	if health_bar:
		health_bar.max_value = max_health

# --- Setup ---
func configure_from_id(id: String):
	stats = GameData.karts.get(id)
	
	max_health = stats.max_health
	current_health = max_health
	
	if not stats:
		printerr("Kart ID not found: ", id)
		return

	# Apply Visuals
	sprite.texture = load("res://assets/karts/%s.png" % stats.id)
	_apply_dimensions(stats.length, stats.width)
	weight = max(stats.length * stats.width, 1.0)
	
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
	_process_waypoints()
	_gather_input()
	_apply_physics(delta)
	
	if health_anchor:
		health_anchor.global_rotation = 0
		# Offset it above the kart
		#health_anchor.global_position = global_position + Vector2(0, -20)

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
	# 1. Decay the bump velocity (friction)
	bump_velocity = bump_velocity.move_toward(Vector2.ZERO, bump_decay * delta)
	
	# 2. Add bump velocity to the standard engine velocity
	velocity = (transform.x * current_speed) + bump_velocity
	var impact_velocity = velocity
	move_and_slide()
	
	# E. Collision Handling
	_handle_collisions(impact_velocity)

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
	rpc("on_damaged_visual")
	
	if current_health <= 0:
		_break_down()

func _break_down():
	is_stunned = true
	current_health = 0
	
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
	if slot_index < 0 or slot_index >= power_inventory.size(): 
		return
	
	if slot_on_cooldown[slot_index]:
		return
	
	var power = power_inventory[slot_index]
	if not power: 
		return

	# Only the local player (authority) can initiate the power use
	if is_multiplayer_authority():
		# Notify the server and all clients to play the effect
		rpc("activate_power_effect", slot_index)

@rpc("call_local", "reliable")
func activate_power_effect(slot_index: int):
	var power = power_inventory[slot_index]
	slot_on_cooldown[slot_index] = true
	cooldown_started.emit(slot_index, power.cooldown)
	
	# Only the server spawns the actual projectile node
	# The MultiplayerSpawner will handle replicating it to others
	if multiplayer.is_server():
		PowerManager.activate_power(self, power)
	
	# Start cooldown locally on all clients for UI/logic purposes
	await get_tree().create_timer(power.cooldown).timeout
	slot_on_cooldown[slot_index] = false

@rpc("call_local")
func on_damaged_visual():
	# Flash Red
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	

func _process_waypoints():
	var track = GameData.current_track
	if not track or track.waypoints.is_empty():
		return
	var target = track.waypoints[current_waypoint_index]
	# Account for track scaling if necessary (matches track.gd logic)
	var scaled_target = target * scale 
	
	var dist = global_position.distance_to(scaled_target)
	
	if dist < wp_threshold:
		_advance_waypoint(track.waypoints.size())

func _advance_waypoint(total_waypoints: int):
	# Detect Lap Completion
	if current_waypoint_index == total_waypoints - 1:
		current_lap += 1
		emit_signal("lap_finished", current_lap)
		print(name, " started lap: ", current_lap + 1)
		
		if current_lap >= GameData.current_track.laps_required:
			laps_finished = true
			race_finished.emit(name)
			_declare_victory()
	
	# Move to next index
	current_waypoint_index = (current_waypoint_index + 1) % total_waypoints

func _declare_victory():
	# Stop the kart
	current_speed = 0
	is_stunned = true # Reusing stun logic to disable input
	print("WINNER: ", name)

func update_health_bar():
	if not health_bar:
		return
	
	health_bar.value = current_health
	health_bar.visible = (current_health < max_health)
	
	# Calculate percentage for color coding
	var health_pct = float(current_health) / float(max_health)
	
	var new_color: Color = Color.SEA_GREEN
	if health_pct <= 0.2:
		new_color = Color.RED
	elif health_pct <= 0.5:
		new_color = Color.YELLOW
	
	var style = health_bar.get_theme_stylebox("fill").duplicate()
	if style is StyleBoxFlat:
		style.bg_color = new_color
	health_bar.add_theme_stylebox_override("fill", style)

func _apply_dimensions(target_length: float, target_width: float):
	# A. Resize Collision Shape
	# We duplicate the shape so we don't affect other instances sharing this resource
	if collider.shape is RectangleShape2D:
		collider.shape = collider.shape.duplicate()
		collider.shape.size = Vector2(target_length, target_width)
	
	# B. Resize Sprite
	if sprite.texture:
		var tex_size = sprite.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			# Scale = Target / Original
			# Assuming Sprite is oriented Right (X-axis)
			sprite.scale.x = target_length / tex_size.x
			sprite.scale.y = target_width / tex_size.y

# This function is called by the aggressor via RPC
@rpc("any_peer", "call_local")
func receive_bump(force: Vector2):
	bump_velocity += force
	
func _handle_collisions(my_impact_velocity: Vector2):
	# 1. COOLDOWN CHECK
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_bump_time < bump_cooldown:
		return

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var body = collision.get_collider()
		
		if body is Kart:
			_apply_bump_to_other(body, collision.get_normal(), my_impact_velocity)
			
			last_bump_time = current_time 
			break

func _apply_bump_to_other(other_kart: Kart, normal: Vector2, my_impact_velocity: Vector2):
	var push_dir = -normal
	
	# Use the SNAPSHOTTED velocity for the check
	var my_speed = my_impact_velocity.length()
	
	if my_speed > 100.0: 
		var weight_ratio = weight / max(other_kart.weight, 1.0)
		var impact_force = push_dir * my_speed * weight_ratio * 0.75
		
		other_kart.rpc("receive_bump", impact_force)
		
		# Apply recoil to ourselves
		bump_velocity += normal * my_speed * 0.3
