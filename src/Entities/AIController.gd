extends Node

# References
@onready var kart = get_parent()

# Pathfinding State
var waypoints: Array = []
var current_wp_index = 0
var wp_threshold = 100.0 # How close we need to get to target the next one

# Obstacle Avoidance (Raycasts)
var ray_left: RayCast2D
var ray_right: RayCast2D

func _ready():
	# 1. Load Waypoints from Global Data
	for p in GameData.current_track.waypoints:
		waypoints.append(Vector2(p["x"], p["y"]))
			
	# 2. Setup Raycasts (Eyes) dynamically
	ray_left = _create_ray(Vector2(50, -30)) # 50px forward, 30px left
	ray_right = _create_ray(Vector2(50, 30)) # 50px forward, 30px right

func _create_ray(target_pos):
	var ray = RayCast2D.new()
	ray.target_position = target_pos
	ray.enabled = true
	kart.call_deferred("add_child", ray)
	return ray

func _physics_process(_delta):
	if waypoints.is_empty(): return
	
	# --- 1. FIND TARGET ---
	var target = waypoints[current_wp_index]
	var distance = kart.global_position.distance_to(target)
	
	if distance < wp_threshold:
		current_wp_index = (current_wp_index + 1) % waypoints.size()
		target = waypoints[current_wp_index]
		
	# --- 2. STEERING LOGIC ---
	# Calculate angle difference between "Facing" and "Target"
	var desired_direction = (target - kart.global_position).normalized()
	var current_direction = Vector2.RIGHT.rotated(kart.rotation)
	var angle_diff = current_direction.angle_to(desired_direction)
	
	# Base steering towards waypoint
	var steer = clamp(angle_diff * 2.0, -1.0, 1.0)
	
	# --- 3. AVOIDANCE OVERRIDE ---
	# If about to hit a wall, steer hard away
	if ray_left.is_colliding():
		steer = 1.0 # Turn Right
	elif ray_right.is_colliding():
		steer = -1.0 # Turn Left
		
	# --- 4. OUTPUT TO KART ---
	kart.steer_input = steer
	kart.throttle_input = 1.0 # Always gas (simple AI)
	
	# Slow down for sharp turns
	if abs(angle_diff) > 1.0: # If turn is > 57 degrees
		kart.throttle_input = 0.5 
		
	_handle_combat()

func _handle_combat():
	# Simple random logic: If we have an item, use it occasionally
	if randf() < 0.01: # 1% chance per frame (~once every 1.5 sec)
		kart.use_power(0)
