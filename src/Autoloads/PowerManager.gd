class_name Power
extends Node

@onready var proj_scene = preload("res://src/Entities/Projectile.tscn")

func activate_power(kart: Kart, power: PowerDef):
	var type = power.type
	
	match type:
		"projectile":
			fire_projectile(kart, power)
		"buff":
			apply_buff(kart, power)
		"hazard":
			drop_hazard(kart, power)

func fire_projectile(kart: Kart, data: PowerDef):
	var proj: Projectile = proj_scene.instantiate()
	proj.shooter_id = kart.name.to_int()
	
	# Visuals
	proj.get_node("Sprite2D").texture = load("res://assets/powers/%s.png"%data.id)
	
	# Stats
	proj.speed = data.speed
	proj.damage = data.damage
	proj.shooter_id = kart.name
	
	# Behavior Configuration
	proj.behavior = data.projectile_behavior
	proj.homing_turn_speed = data.turn_speed
	proj.detection_radius = data.detection_radius
	
	# --- Position & Rotation Logic ---
	
	# Default Spawn Offset (Forward)
	var sprite: Sprite2D = kart.get_node("Sprite2D")
	var kart_length = sprite.texture.get_width() * sprite.scale.x
	var forward_dist = (kart_length / 2.0) + 15.0
	
	if data.projectile_behavior == "orbit":
		# Setup Orbit
		proj.orbit_center = kart
		proj.orbit_duration = data.duration
		proj.orbit_radius = 100.0 # Hardcoded or add to PowerDef if needed
		
		# Initial position (start at current rotation)
		var offset = Vector2(proj.orbit_radius, 0).rotated(kart.rotation)
		proj.global_position = kart.global_position + offset
		proj.rotation = kart.rotation + (PI / 2.0)
		
	elif data.projectile_behavior == "backward":
		# Setup Backward
		var offset = Vector2(-forward_dist, 0).rotated(kart.rotation)
		proj.global_position = kart.global_position + offset
		
		# Rotate 180 degrees from kart
		proj.rotation = kart.rotation + PI
		
	else:
		# Standard (Straight / Homing)
		var offset = Vector2(forward_dist, 0).rotated(kart.rotation)
		proj.global_position = kart.global_position + offset
		proj.rotation = kart.rotation
	
	get_tree().current_scene.add_child(proj, true)

func drop_hazard(kart: Kart, _data: PowerDef):
	# Hazards spawn BEHIND the car
	var hazard = load("res://src/Entities/Hazard.tscn").instantiate()
	
	var spawn_offset = kart.transform.x * -40 
	hazard.global_position = kart.global_position + spawn_offset
	
	get_tree().current_scene.add_child(hazard)

func apply_buff(kart: Kart, data: PowerDef):
	# Example: Speed Boost
	if data.get("stat_target") == "speed":
		kart.max_speed += data.amount
		
		# Reset after duration
		await get_tree().create_timer(data.duration).timeout
		kart.max_speed -= data.amount
