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
	# Configure visuals
	proj.get_node("Sprite2D").texture = load("res://assets/powers/%s.png"%data.id)
	
	proj.speed = data.speed
	proj.damage = data.damage
	
	var sprite: Sprite2D = kart.get_node("Sprite2D")
	var kart_length = sprite.texture.get_width() * sprite.scale.x
	var forward_distance = (kart_length / 2.0) + 10.0
	var local_offset = Vector2(forward_distance, 0)
	var global_offset = local_offset.rotated(kart.rotation)
	proj.global_position = kart.global_position + global_offset
	
	# Rotate to face the same way as the car
	proj.rotation = kart.rotation
	
	get_tree().current_scene.add_child(proj)

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
