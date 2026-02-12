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
	var proj: Projectile = proj_scene.instantiate()
	proj.shooter_id = kart.name.to_int()
	
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
	
	# Position Logic
	var sprite: Sprite2D = kart.get_node("Sprite2D")
	var kart_length = sprite.texture.get_width() * sprite.scale.x
	var forward_dist = (kart_length / 2.0) + (data.length / 2.0) + 10.0
	
	if data.projectile_behavior == "Orbit":
		proj.orbit_center = kart
		proj.orbit_duration = data.duration
		proj.orbit_radius = 100.0
		var offset = Vector2(proj.orbit_radius, 0).rotated(kart.rotation)
		proj.global_position = kart.global_position + offset
		proj.rotation = kart.rotation + (PI / 2.0)
		
	elif data.projectile_behavior == "Backward":
		var offset = Vector2(-forward_dist, 0).rotated(kart.rotation)
		proj.global_position = kart.global_position + offset
		proj.rotation = kart.rotation + PI
		
	else:
		var offset = Vector2(forward_dist, 0).rotated(kart.rotation)
		proj.global_position = kart.global_position + offset
		proj.rotation = kart.rotation
	
	get_tree().current_scene.add_child(proj, true)

func drop_hazard(kart: Kart, data: PowerDef):
	var hazard_scene = load("res://src/Entities/Hazard.tscn")
	var hazard = hazard_scene.instantiate()
	
	# Stats & Dimensions
	hazard.damage = data.damage
	hazard.duration = data.duration
	hazard.shooter_id = kart.name
	hazard.length = data.length
	hazard.width = data.width
	
	# Visuals
	var sprite: Sprite2D = hazard.get_node("Sprite2D")
	sprite.texture = load("res://assets/powers/%s.png" % data.id)
	
	# Determine Deployment (Lob vs Drop)
	if data.projectile_behavior == "Forward":
		# Lob Forward
		var forward_vector = Vector2.RIGHT.rotated(kart.rotation)
		hazard.global_position = kart.global_position + (forward_vector * 60.0)
		hazard.target_pos = kart.global_position + (forward_vector * 300.0)
		hazard.lob_speed = data.speed
	else:
		# Drop Behind
		var backward_vector = Vector2.LEFT.rotated(kart.rotation)
		hazard.global_position = kart.global_position + (backward_vector * 60.0)
		hazard.target_pos = Vector2.ZERO # Active immediately
	
	get_tree().current_scene.add_child(hazard, true)

func apply_buff(kart: Kart, data: PowerDef):
	if data.stat_target == "max_speed":
		kart.max_speed += data.amount
		await get_tree().create_timer(data.duration).timeout
		kart.max_speed -= data.amount
	elif data.stat_target == "health":
		kart.current_health = min(kart.current_health + data.amount, kart.max_health)
		kart.update_health_bar()
