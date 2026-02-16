class_name Projectile
extends Area2D

@export var launch_sfx: AudioStream
@export var sound_max_distance: float = 500.0 # Pixels. Sounds beyond this are silent.

# Config
var speed = 0
var damage = 0
var shooter_id = 0
var behavior: String = "Forward"

# New Config
var can_bounce: bool = false
var max_lifetime: float = 0.0 # 0 means infinite (until hit)
var current_lifetime: float = 0.0

# Dimensions
var length: float = 40.0
var width: float = 40.0

# Homing Config
var homing_turn_speed: float = 2.0
var detection_radius: float = 300.0
var current_target: Node2D = null

# Orbit Config
var orbit_center: Node2D = null
var orbit_radius: float = 70.0
var orbit_angle: float = 0.0
var orbit_duration: float = 5.0
var orbit_timer: float = 0.0

var stat_target: String = ""
var stat_amount: float = 0.0
var stat_duration: float = 0.0

func _ready():
	connect("body_entered", _on_hit)
	
	# Apply dynamic size
	_apply_dimensions()
	
	if behavior == "Orbit" and orbit_center:
		orbit_angle = global_position.angle_to_point(orbit_center.global_position)
		
	# Play the spawn sound with distance checks
	_setup_audio()

func _setup_audio():
	if not launch_sfx:
		return

	# We create the player programmatically so you don't have to edit every scene manually
	var sfx_player = AudioStreamPlayer2D.new()
	sfx_player.stream = launch_sfx
	sfx_player.bus = "SFX" # Route to your SFX bus
	
	# Key Feature: Distance Culling
	# The sound will attenuate (fade out) over this distance
	sfx_player.max_distance = sound_max_distance
	
	# Optional: Adjust 'panning_strength' if you want it less directional (0.0 is mono, 1.0 is full spatial)
	sfx_player.panning_strength = 1.0 
	
	add_child(sfx_player)
	sfx_player.play()

func _apply_dimensions():
	var sprite = get_node_or_null("Sprite2D")
	if sprite and sprite.texture:
		var tex_size = sprite.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			sprite.scale = Vector2(length / tex_size.x, width / tex_size.y)
	
	var col = get_node_or_null("CollisionShape2D")
	if col:
		col.shape = col.shape.duplicate()
		if col.shape is RectangleShape2D:
			col.shape.size = Vector2(length, width)
		elif col.shape is CircleShape2D:
			col.shape.radius = max(length, width) / 2.0

func _physics_process(delta):
	# Handle Lifetime for Bouncing Projectiles
	if max_lifetime > 0:
		current_lifetime += delta
		if current_lifetime >= max_lifetime:
			_destroy() # FIX: Use safe destroy
			return

	match behavior:
		"Orbit":
			_process_orbit(delta)
		"Homing":
			_process_homing(delta)
			_move_forward(delta)
		_:
			_move_forward(delta)

func _move_forward(delta):
	var move_vec = Vector2.RIGHT.rotated(rotation) * speed * delta
	
	# --- Bouncing Logic ---
	if can_bounce:
		var space_state = get_world_2d().direct_space_state
		# Raycast forward to detect walls before we move into them
		var query = PhysicsRayQueryParameters2D.create(global_position, global_position + move_vec * 1.5)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		
		var result = space_state.intersect_ray(query)
		if result and result.collider is StaticBody2D: # Assuming walls are StaticBody2D
			var normal = result.normal
			var direction = Vector2.RIGHT.rotated(rotation)
			var new_dir = direction.bounce(normal)
			
			rotation = new_dir.angle()
			# Slightly nudge away from wall to prevent sticking
			global_position = result.position + (normal * 5.0)
			return
	# ----------------------

	position += move_vec

func _process_orbit(delta):
	orbit_timer += delta
	if orbit_timer > orbit_duration:
		_destroy() # FIX: Use safe destroy
		return

	if not is_instance_valid(orbit_center):
		_destroy() # FIX: Use safe destroy
		return
		
	var angular_speed = speed / orbit_radius
	orbit_angle += angular_speed * delta
	global_position = orbit_center.global_position + Vector2(orbit_radius, 0).rotated(orbit_angle)
	rotation = orbit_angle + (PI / 2.0)

func _process_homing(delta):
	if not is_instance_valid(current_target):
		current_target = _find_target_in_front()
	
	if is_instance_valid(current_target):
		var direction_to_target = (current_target.global_position - global_position).normalized()
		var current_direction = Vector2.RIGHT.rotated(rotation)
		var angle_diff = current_direction.angle_to(direction_to_target)
		var turn_step = homing_turn_speed * delta
		rotation += clamp(angle_diff, -turn_step, turn_step)

func _find_target_in_front() -> Node2D:
	var best_target = null
	var closest_dist = detection_radius
	var potential_targets = get_tree().current_scene.get_children()
	
	for node in potential_targets:
		if node is Kart and node.name != str(shooter_id):
			var dist = global_position.distance_to(node.global_position)
			if dist < closest_dist:
				var to_target = (node.global_position - global_position).normalized()
				var forward = Vector2.RIGHT.rotated(rotation)
				if forward.dot(to_target) > 0.0:
					closest_dist = dist
					best_target = node
	return best_target

func _on_hit(body):
	if body.name == str(shooter_id): return
	
	# Hit a Wall (or non-damageable object)
	if not body.has_method("take_damage"):
		if behavior == "Orbit": return
		
		# If we can bounce, we ignore this collision (physics raycast handles the bounce)
		if can_bounce:
			return
			
		_destroy()
		return

	# Hit a Kart
	if body.has_method("take_damage"):
		if body.get("is_shield_up"):
			return
		if is_multiplayer_authority():
			# 1. Apply Damage
			if damage > 0:
				body.rpc_id(body.get_multiplayer_authority(), "take_damage", damage)
			
			# 2. Apply Stat Modifier
			if stat_target != "" and stat_duration > 0:
				body.rpc_id(body.get_multiplayer_authority(), "apply_stat_modifier", stat_target, stat_amount, stat_duration)
			
		_destroy()

func _destroy():
	if is_multiplayer_authority():
		# Server: Actually delete the object.
		# This triggers the "despawn" signal to clients.
		queue_free()
	else:
		# Client: Just hide it immediately so it looks responsive.
		# DO NOT delete it. Wait for the Server's packet to delete it.
		visible = false
		set_physics_process(false)
		if has_node("CollisionShape2D"):
			$CollisionShape2D.set_deferred("disabled", true)
