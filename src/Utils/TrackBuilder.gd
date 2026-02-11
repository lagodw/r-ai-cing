class_name TrackBuilder extends Node

const RED_THRESHOLD = 0.5
const GREEN_BLUE_LIMIT = 0.2
const SIMPLIFICATION = 2.0

static func generate_walls_from_texture(texture: Texture2D, parent_node: Node, centered: bool = false):
	var image: Image = texture.get_image()
	# Ensure image is in a format we can read easily
	if image.is_compressed():
		image.decompress()
		
	var bitmap = BitMap.new()
	bitmap.create(image.get_size())
	
	# 1. Precise Scan for RED pixels
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color = image.get_pixel(x, y)
			# Only pick pixels that are strongly Red and weakly Green/Blue
			if color.r > RED_THRESHOLD and color.g < GREEN_BLUE_LIMIT and color.b < GREEN_BLUE_LIMIT:
				bitmap.set_bit(x, y, true)
			else:
				bitmap.set_bit(x, y, false)
	
	# 2. Convert to Polygons
	# This will return an Array[PackedVector2Array], one for each "island" of red
	var polygons = bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, image.get_size()), SIMPLIFICATION)
	
	var offset = Vector2.ZERO
	if centered:
		offset = -Vector2(image.get_width(), image.get_height()) / 2.0
	
	# 3. Create individual CollisionPolygon2D nodes for each island
	for poly in polygons:
		if poly.size() < 3: continue # Skip invalid polygons
		
		var collider = CollisionPolygon2D.new()
		var centered_poly = PackedVector2Array()
		
		for point in poly:
			centered_poly.append(point + offset)
			
		collider.polygon = centered_poly
		# Set build mode to Segments to avoid "filling" the middle if it's a loop
		collider.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
		parent_node.add_child(collider)

static func generate_path_automatically(context: Node2D, start_pos: Vector2, look_ahead: float = 200.0, collision_mask: int = 1) -> Array[Vector2]:
	var path: Array[Vector2] = []
	path.append(start_pos)
	
	# Access the Physics State
	var space_state = context.get_world_2d().direct_space_state
	
	var current_pos = start_pos
	var current_angle = 0.0 # We will auto-detect start angle below
	
	# --- CONFIG ---
	var step_size = 40.0
	var max_steps = 3000
	var steering_speed = 0.4 # Smooth turning
	# --------------

	# 1. AUTO-DETECT START ROTATION (Physics Version)
	# Scan 360 degrees to find the longest open path
	var max_start_dist = -1.0
	
	for d in range(0, 360, 10):
		var rad = deg_to_rad(d)
		var dir = Vector2.RIGHT.rotated(rad)
		var target = current_pos + (dir * look_ahead)
		
		# Create Ray Query
		var query = PhysicsRayQueryParameters2D.create(current_pos, target, collision_mask)
		var result = space_state.intersect_ray(query)
		
		var dist = look_ahead
		if result:
			dist = current_pos.distance_to(result.position)
			
		if dist > max_start_dist:
			max_start_dist = dist
			current_angle = rad
			
	print("Physics Pathfinding: Start Angle ", rad_to_deg(current_angle))

	# 2. MAIN LOOP
	for i in range(max_steps):
		var weighted_vector_sum = Vector2.ZERO
		var total_weight = 0.0
		var rays_cast = 0
		
		# Fan Scan (-90 to +90 degrees)
		for angle_offset in range(-90, 91, 10):
			var radians = current_angle + deg_to_rad(angle_offset)
			var dir = Vector2.RIGHT.rotated(radians)
			var target = current_pos + (dir * look_ahead)
			
			var query = PhysicsRayQueryParameters2D.create(current_pos, target, collision_mask)
			var result = space_state.intersect_ray(query)
			
			var dist = look_ahead
			if result:
				dist = current_pos.distance_to(result.position)
			
			# WEIGHTING: Squared distance rewards open paths heavily
			var weight = pow(dist, 2)
			
			weighted_vector_sum += dir * weight
			total_weight += weight
			rays_cast += 1
			
		if total_weight > 0:
			# Calculate Best Direction
			var target_dir = (weighted_vector_sum / total_weight).normalized()
			var target_angle = target_dir.angle()
			
			# Smooth Steering
			current_angle = lerp_angle(current_angle, target_angle, steering_speed)
			
			# Move
			var move_dir = Vector2.RIGHT.rotated(current_angle)
			var next_pos = current_pos + (move_dir * step_size)
			
			# Safety Check: Did we just drive INSIDE a wall?
			# We cast a tiny ray from current to next to ensure we don't phase through thin walls
			var safety_query = PhysicsRayQueryParameters2D.create(current_pos, next_pos, collision_mask)
			if space_state.intersect_ray(safety_query):
				print("Pathfinding blocked at step ", i)
				break
				
			path.append(next_pos)
			current_pos = next_pos
			
			# Loop Complete Check
			if i > 20 and current_pos.distance_to(start_pos) < step_size * 1.5:
				print("Track Loop Closed!")
				break
		else:
			break
			
	return path
