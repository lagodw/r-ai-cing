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

	for i in range(count):
		var proj: Projectile = proj_scene.instantiate()
		
		# Visuals & Dimensions
		proj.get_node("Sprite2D").texture = load("res://assets/powers/%s.png" % data.id)
		proj.length = data.length
		proj.width = data.width
		
		# Stats
		proj.speed = data.speed
		proj.damage = data.damage
		proj.shooter_id = kart.name
		proj.behavior = data.projectile_behavior
		proj.homing_turn_speed = data.turn_speed
		proj.detection_radius = data.detection_radius
		proj.can_bounce = data.can_bounce # Pass the new capability
		proj.max_lifetime = data.duration
		
		# --- Rotation & Position Logic ---
		
		# 1. Determine base rotation (Forward or Backward)
		var base_rotation = kart.rotation
		if data.projectile_behavior == "Backward":
			base_rotation += PI
			
		# 2. Apply spread offset
		var current_angle = base_rotation
		if count > 1 and data.projectile_behavior != "Orbit":
			current_angle += start_angle_offset + (angle_step * i)
		
		# 3. Apply to Projectile
		if data.projectile_behavior == "Orbit":
			# Orbit logic handles its own position, but we pass data
			proj.orbit_center = kart
			proj.orbit_duration = data.duration
			proj.orbit_radius = 100.0
			# If we have multiple orbits, this logic creates them stacked. 
			# (Orbit spacing would require offsetting the initial orbit_angle in Projectile.gd)
			var offset = Vector2(proj.orbit_radius, 0).rotated(kart.rotation)
			proj.global_position = kart.global_position + offset
			proj.rotation = kart.rotation + (PI / 2.0)
			
		else:
			# Standard Forward/Backward/Homing logic
			var offset_vector = Vector2(forward_dist, 0).rotated(current_angle)
			proj.global_position = kart.global_position + offset_vector
			proj.rotation = current_angle
		
		get_tree().current_scene.add_child(proj, true)

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
