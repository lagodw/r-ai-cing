class_name Power
extends Node

@onready var proj_scene = preload("res://src/Entities/Projectile.tscn")

func activate_power(kart: Kart, power: PowerDef):
	var type = power.type
	match type:
		"Projectile":
			fire_projectile(kart, power)
		"Buff":
			apply_buff(kart, power)
		"Hazard":
			drop_hazard(kart, power)

func fire_projectile(kart: Kart, data: PowerDef):
	# 1. Only the Server spawns networked objects
	if not multiplayer.is_server():
		return

	# Determine how many to shoot
	var count = max(1, data.projectile_count)
	
	# Configuration for the arc (90 degrees total)
	var spread_angle_deg = 90.0
	var spread_rad = deg_to_rad(spread_angle_deg)
	
	# Calculate the starting offset angle so the arc is centered
	var start_angle_offset = 0.0
	var angle_step = 0.0
	
	if count > 1:
		start_angle_offset = -spread_rad / 2.0
		angle_step = spread_rad / (count - 1)

	# Pre-calculate kart dimensions
	var sprite: Sprite2D = kart.get_node("Sprite2D")
	var kart_length = sprite.texture.get_width() * sprite.scale.x
	var forward_dist = (kart_length / 2.0) + (data.length / 2.0) + 10.0

	# Find the Spawner
	# We assume the Kart is inside the Track scene
	var track = kart.get_tree().current_scene
	if not track.has_node("ProjectileSpawner"):
		printerr("PowerManager: ProjectileSpawner not found!")
		return
	var spawner = track.get_node("ProjectileSpawner")

	for i in range(count):
		# --- Calculate Transform Logic (No Instantiation) ---
		var spawn_pos = Vector2.ZERO
		var spawn_rot = 0.0
		
		# 1. Determine base rotation (Forward or Backward)
		var base_rotation = kart.rotation
		if data.projectile_behavior == "Backward":
			base_rotation += PI
			
		# 2. Apply spread offset
		var current_angle = base_rotation
		if count > 1 and data.projectile_behavior != "Orbit":
			current_angle += start_angle_offset + (angle_step * i)
		
		# 3. Calculate Final Position/Rotation
		if data.projectile_behavior == "Orbit":
			var orbit_radius = 100.0 # From your original code
			var offset = Vector2(orbit_radius, 0).rotated(kart.rotation)
			spawn_pos = kart.global_position + offset
			spawn_rot = kart.rotation + (PI / 2.0)
		else:
			# Standard Forward/Backward/Homing logic
			var offset_vector = Vector2(forward_dist, 0).rotated(current_angle)
			spawn_pos = kart.global_position + offset_vector
			spawn_rot = current_angle
		
		# --- Prepare Network Data ---
		var spawn_data = {
			"position": spawn_pos,
			"rotation": spawn_rot,
			"shooter_id": kart.name,
			"behavior": data.projectile_behavior,
			"speed": data.speed,
			"damage": data.damage,
			"length": data.length,
			"width": data.width,
			"texture_path": "res://assets/powers/%s.png" % data.id,
			
			# Extra Properties
			"homing_turn_speed": data.turn_speed,
			"detection_radius": data.detection_radius,
			"can_bounce": data.can_bounce,
			"max_lifetime": data.duration,
			"orbit_duration": data.duration
		}
		
		if data.projectile_behavior == "Orbit":
			spawn_data["orbit_center_path"] = kart.get_path()
			
		# --- Spawn ---
		spawner.spawn(spawn_data)

func drop_hazard(kart: Kart, data: PowerDef):
	var hazard_scene = load("res://src/Entities/Hazard.tscn")
	
	# Logic similar to projectiles for spread
	var count = max(1, data.projectile_count)
	var spread_angle_deg = 90.0
	var spread_rad = deg_to_rad(spread_angle_deg)
	
	var start_angle_offset = 0.0
	var angle_step = 0.0
	
	if count > 1:
		start_angle_offset = -spread_rad / 2.0
		angle_step = spread_rad / (count - 1)
	
	for i in range(count):
		var hazard = hazard_scene.instantiate()
		
		# Stats & Dimensions
		hazard.damage = data.damage
		hazard.duration = data.duration
		hazard.shooter_id = kart.name
		hazard.length = data.length
		hazard.width = data.width
		hazard.lob_speed = data.speed
		
		# Visuals
		var sprite: Sprite2D = hazard.get_node("Sprite2D")
		sprite.texture = load("res://assets/powers/%s.png" % data.id)
		
		# Determine Base Direction
		var base_rotation = kart.rotation
		if data.projectile_behavior != "Forward":
			base_rotation += PI # Backward
			
		# Apply Spread
		var current_angle = base_rotation
		if count > 1:
			current_angle += start_angle_offset + (angle_step * i)
		
		var move_vector = Vector2.RIGHT.rotated(current_angle)
		
		# Initial Spawn Position (Offset from kart)
		hazard.global_position = kart.global_position + (move_vector * 60.0)
		
		# Determine Deployment (Lob vs Drop)
		if data.projectile_behavior == "Forward":
			# Lob Forward
			hazard.travel_dir = move_vector
			hazard.max_travel_dist = 300.0
		else:
			# Drop Behind
			hazard.travel_dir = Vector2.ZERO # No movement
			hazard.max_travel_dist = 0.0
		
		get_tree().current_scene.add_child(hazard, true)

func apply_buff(kart: Kart, data: PowerDef):
	if data.stat_target == "max_speed":
		kart.max_speed += data.amount
		await get_tree().create_timer(data.duration).timeout
		kart.max_speed -= data.amount
	elif data.stat_target == "health":
		kart.current_health = min(kart.current_health + data.amount, kart.max_health)
		kart.update_health_bar()
