extends Node

@onready var kart = get_parent()

# Pathfinding
var waypoints: Array = []
var current_wp_index = 0
var wp_threshold = 150.0 

# Sensors
var ray_l: RayCast2D
var ray_r: RayCast2D
var ray_c: RayCast2D

# State
var stuck_timer: float = 0.0
var is_reversing: bool = false
var reverse_timer: float = 0.0

func _ready():
	if GameData.current_track and GameData.current_track.waypoints:
		waypoints = GameData.current_track.waypoints
		# Optimization: Find the closest waypoint immediately so we don't start at index 0 if we spawned at index 10
		current_wp_index = _find_closest_waypoint_index()
	
	ray_c = _add_whisker(Vector2(150, 0))
	ray_l = _add_whisker(Vector2(80, -60))
	ray_r = _add_whisker(Vector2(80, 60))

func _add_whisker(target: Vector2) -> RayCast2D:
	var ray = RayCast2D.new()
	ray.target_position = target
	ray.enabled = true
	ray.collide_with_bodies = true
	ray.collide_with_areas = false
	kart.call_deferred("add_child", ray)
	return ray

func _physics_process(delta):
	if waypoints.is_empty(): return
	
	# --- 1. TARGETING ---
	var target = waypoints[current_wp_index]
	var dist = kart.global_position.distance_to(target)
	
	# Advance to next waypoint
	if dist < wp_threshold:
		current_wp_index = (current_wp_index + 1) % waypoints.size()
		target = waypoints[current_wp_index]

	# Vector Math
	var desired_dir = (target - kart.global_position).normalized()
	var current_dir = Vector2.RIGHT.rotated(kart.rotation)
	var angle_to_target = current_dir.angle_to(desired_dir)
	
	# --- 2. WRONG WAY DETECTION ---
	# If the angle to target is greater than 90 degrees (approx 1.5 radians), we are facing backwards
	var is_wrong_way = abs(angle_to_target) > 1.5
	
	# --- 3. STUCK DETECTION ---
	# If we are pushing gas but not moving, we are stuck.
	if kart.input_throttle > 0 and kart.velocity.length() < 20:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
	
	# Trigger Reverse Maneuver
	if stuck_timer > 1.0:
		is_reversing = true
		reverse_timer = 1.5 # Reverse for 1.5 seconds
		stuck_timer = 0.0
		
	if is_reversing:
		_handle_reverse_maneuver(delta)
		return # Skip normal steering

	# --- 4. STEERING LOGIC ---
	if is_wrong_way:
		# EMERGENCY MODE: Ignore walls, just turn around
		# If moving fast forward, brake first
		if kart.velocity.length() > 100 and kart.input_throttle > 0:
			kart.input_throttle = -1.0 # Brake
			kart.input_steer = 0.0 # Don't spin while braking hard
		else:
			# Stopped or slow? Turn hard.
			kart.input_throttle = 0.5 # Gentle gas
			kart.input_steer = 1.0 if angle_to_target > 0 else -1.0
			
	else:
		# NORMAL MODE: Path follow + Wall Avoidance
		
		# Base steering towards waypoint
		var steer = angle_to_target
		
		# Raycast Avoidance (Only when going forward!)
		if ray_l.is_colliding(): steer += 1.5
		if ray_r.is_colliding(): steer -= 1.5
		if ray_c.is_colliding(): steer += 1.0 if steer > 0 else -1.0
		
		kart.input_steer = clamp(steer * 2.0, -1.0, 1.0)
		
		# Cornering speed control
		if abs(steer) > 0.5:
			kart.input_throttle = 0.6
		else:
			kart.input_throttle = 1.0

func _handle_reverse_maneuver(delta):
	reverse_timer -= delta
	if reverse_timer <= 0:
		is_reversing = false
		return
		
	# Reverse straight back, or turn opposite to obstacle
	kart.input_throttle = -0.8
	
	# If left whisker is hit, steer Right (which in reverse pushes tail Left)
	# It's confusing, but usually keeping steer 0 or inverting helps unstick
	kart.input_steer = 0.0 

func _find_closest_waypoint_index() -> int:
	var closest_idx = 0
	var min_dist = INF
	for i in range(waypoints.size()):
		var d = kart.global_position.distance_squared_to(waypoints[i])
		if d < min_dist:
			min_dist = d
			closest_idx = i
	return closest_idx
