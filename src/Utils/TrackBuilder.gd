class_name TrackBuilder extends Node

const RED_THRESHOLD = 0.5
const GREEN_BLUE_LIMIT = 0.2
const MAGENTA_THRESHOLD = 0.8
const GREEN_LIMIT = 0.2       
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

static func generate_path_automatically(context: Node2D, start_pos: Vector2, look_ahead: float = 200.0, collision_mask: int = 1) -> Dictionary:
	var path: Array[Vector2] = []
	path.append(start_pos)
	
	var space_state = context.get_world_2d().direct_space_state
	var current_pos = start_pos
	var current_angle = 0.0
	
	# --- CONFIG ---
	var step_size = 40.0
	var max_steps = 3000
	var steering_speed = 0.4 
	# --------------

	# 1. AUTO-DETECT START ROTATION
	var max_start_dist = -1.0
	
	for d in range(0, 360, 10):
		var rad = deg_to_rad(d)
		var dir = Vector2.RIGHT.rotated(rad)
		var target = current_pos + (dir * look_ahead)
		
		var query = PhysicsRayQueryParameters2D.create(current_pos, target, collision_mask)
		var result = space_state.intersect_ray(query)
		
		var dist = look_ahead
		if result:
			dist = current_pos.distance_to(result.position)
			
		if dist > max_start_dist:
			max_start_dist = dist
			current_angle = rad
			
	print("Physics Pathfinding: Start Angle ", rad_to_deg(current_angle))
	
	# SAVE THE DETECTED ANGLE
	var found_start_angle = current_angle

	# 2. MAIN LOOP (Rest of the function remains mostly the same)
	for i in range(max_steps):
		var weighted_vector_sum = Vector2.ZERO
		var total_weight = 0.0
		
		for angle_offset in range(-90, 91, 10):
			var radians = current_angle + deg_to_rad(angle_offset)
			var dir = Vector2.RIGHT.rotated(radians)
			var target = current_pos + (dir * look_ahead)
			
			var query = PhysicsRayQueryParameters2D.create(current_pos, target, collision_mask)
			var result = space_state.intersect_ray(query)
			
			var dist = look_ahead
			if result:
				dist = current_pos.distance_to(result.position)
			
			var weight = pow(dist, 2)
			weighted_vector_sum += dir * weight
			total_weight += weight
			
		if total_weight > 0:
			var target_dir = (weighted_vector_sum / total_weight).normalized()
			var target_angle = target_dir.angle()
			
			current_angle = lerp_angle(current_angle, target_angle, steering_speed)
			
			var move_dir = Vector2.RIGHT.rotated(current_angle)
			var next_pos = current_pos + (move_dir * step_size)
			
			# Safety check
			var safety_query = PhysicsRayQueryParameters2D.create(current_pos, next_pos, collision_mask)
			if space_state.intersect_ray(safety_query):
				break
				
			path.append(next_pos)
			current_pos = next_pos
			
			if i > 20 and current_pos.distance_to(start_pos) < step_size * 1.5:
				break
		else:
			break
			
	# Return both the path and the angle we found at the start
	return {
		"path": path,
		"angle": found_start_angle
	}

static func measure_track_width(context: Node2D, start_pos: Vector2, forward_angle: float, collision_mask: int = 1) -> float:
	var space_state = context.get_world_2d().direct_space_state
	
	# Calculate vectors perpendicular to the track direction
	var right_dir = Vector2.RIGHT.rotated(forward_angle + PI/2)
	var left_dir = -right_dir
	
	var scan_dist = 2000.0 # Far enough to hit walls
	
	# Raycast Right
	var dist_r = scan_dist
	var query_r = PhysicsRayQueryParameters2D.create(start_pos, start_pos + (right_dir * scan_dist), collision_mask)
	var res_r = space_state.intersect_ray(query_r)
	if res_r:
		dist_r = start_pos.distance_to(res_r.position)
		
	# Raycast Left
	var dist_l = scan_dist
	var query_l = PhysicsRayQueryParameters2D.create(start_pos, start_pos + (left_dir * scan_dist), collision_mask)
	var res_l = space_state.intersect_ray(query_l)
	if res_l:
		dist_l = start_pos.distance_to(res_l.position)
		
	var total = dist_r + dist_l
	print("Track Width Measured: ", total)
	return total

static func find_start_position_from_texture(texture: Texture2D, centered: bool = false) -> Vector2:
	var image: Image = texture.get_image()
	# Ensure image is in a format we can read easily
	if image.is_compressed():
		image.decompress()
	
	var total_pos = Vector2.ZERO
	var pixel_count = 0
	
	# Scan the image for Magenta pixels
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color = image.get_pixel(x, y)
			
			# Check for Magenta: High Red, High Blue, Low Green
			if color.r > MAGENTA_THRESHOLD and color.b > MAGENTA_THRESHOLD and color.g < GREEN_LIMIT:
				total_pos += Vector2(x, y)
				pixel_count += 1
	
	# Calculate the center (average) of all found pixels
	if pixel_count > 0:
		var avg_pos = total_pos / pixel_count
		
		if centered:
			var offset = -Vector2(image.get_width(), image.get_height()) / 2.0
			avg_pos += offset
			
		return avg_pos
	
	return Vector2.INF
	
