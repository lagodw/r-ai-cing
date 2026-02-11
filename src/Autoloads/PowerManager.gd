class_name Power
extends Node

func activate_power(kart: CharacterBody2D, power_id: String):
	# 1. Look up the data from the JSON loaded in GameData
	var data = GameData.powers.get(power_id)
	if not data: 
		print("Power not found: " + power_id)
		return
	
	var type = data.get("type", "projectile")
	
	match type:
		"projectile":
			fire_projectile(kart, data)
		"self_buff":
			apply_buff(kart, data)
		"hazard":
			drop_hazard(kart, data)

func fire_projectile(kart, data):
	var proj = load("res://src/Entities/Projectile.tscn").instantiate()
	
	# Configure visuals
	proj.texture_path = "res://assets/sprites/" + data.get("sprite_file", "bullet.png")
	
	# Spawn at the front of the car
	# transform.x is the Forward Vector of the car
	var spawn_offset = kart.transform.x * 40 
	proj.global_position = kart.global_position + spawn_offset
	
	# Rotate to face the same way as the car
	proj.rotation = kart.rotation
	
	get_tree().current_scene.add_child(proj)

func drop_hazard(kart, _data):
	# Hazards spawn BEHIND the car
	var hazard = load("res://src/Entities/Hazard.tscn").instantiate()
	
	var spawn_offset = kart.transform.x * -40 
	hazard.global_position = kart.global_position + spawn_offset
	
	get_tree().current_scene.add_child(hazard)

func apply_buff(kart, data):
	# Example: Speed Boost
	if data.get("stat_target") == "speed":
		kart.max_speed += data.get("amount", 200)
		
		# Reset after duration
		await get_tree().create_timer(data.get("duration", 2.0)).timeout
		kart.max_speed -= data.get("amount", 200)
