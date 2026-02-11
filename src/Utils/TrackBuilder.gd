class_name TrackBuilder extends Node

const RED_THRESHOLD = 0.5
const GREEN_BLUE_LIMIT = 0.2
const SIMPLIFICATION = 2.0

# Added "centered" parameter
static func generate_walls_from_texture(texture: Texture2D, parent_node: Node, centered: bool = false):
	var image: Image = texture.get_image()
	var bitmap = BitMap.new()
	bitmap.create(image.get_size())
	
	# Scan for RED pixels
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color = image.get_pixel(x, y)
			if color.r > RED_THRESHOLD and color.g < GREEN_BLUE_LIMIT and color.b < GREEN_BLUE_LIMIT:
				bitmap.set_bit(x, y, true)
			else:
				bitmap.set_bit(x, y, false)
	
	var polygons = bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, image.get_size()), SIMPLIFICATION)
	
	# --- THE FIX: Calculate Offset ---
	var offset = Vector2.ZERO
	if centered:
		offset = -Vector2(image.get_width(), image.get_height()) / 2.0
	
	for poly in polygons:
		var collider = CollisionPolygon2D.new()
		# Shift every point in the polygon by the offset
		var centered_poly = PackedVector2Array()
		for point in poly:
			centered_poly.append(point + offset)
			
		collider.polygon = centered_poly
		parent_node.add_child(collider)

static func generate_path_automatically(texture: Texture2D, start_pos: Vector2, centered: bool = false) -> Array[Vector2]:
	var image: Image = texture.get_image()
	var offset = Vector2.ZERO
	if centered:
		offset = Vector2(image.get_width(), image.get_height()) / 2.0
	
	# Convert start_pos (Global) to Image Coordinates (0,0 is Top-Left)
	var current_pixel = start_pos + offset
	
	var path: Array[Vector2] = []
	#var visited_pixels = {} # To prevent backtracking
	
	# Config
	var step_size = 40.0 # How far to step each time
	var max_steps = 500
	#var scan_angle_steps = 16 # Check 16 points around the circle
	
	# Initial direction (Assumed facing Right, or user defined. We'll try to find the road)
	var current_angle = 0.0 
	
	path.append(start_pos)
	
	for i in range(max_steps):
		var best_next_pos = Vector2.ZERO
		var found_valid_step = false
		
		# Scan a semi-circle ahead of us (-90 to +90 degrees)
		# We don't scan behind because we don't want to turn around.
		for angle_offset in range(-100, 101, 20): # Scan wide arc
			var radians = deg_to_rad(current_angle + angle_offset)
			var check_dir = Vector2.RIGHT.rotated(radians)
			var check_pos = current_pixel + (check_dir * step_size)
			
			# Check bounds
			if check_pos.x < 0 or check_pos.y < 0 or check_pos.x >= image.get_width() or check_pos.y >= image.get_height():
				continue
			
			# Check Color (Is it Road? i.e., NOT Red/Wall)
			var color = image.get_pixel(int(check_pos.x), int(check_pos.y))
			var is_wall = (color.r > RED_THRESHOLD and color.g < GREEN_BLUE_LIMIT)
			
			if not is_wall:
				best_next_pos = check_pos
				current_angle += deg_to_rad(angle_offset) # Update facing direction
				found_valid_step = true
				break # Found a path forward!
		
		if found_valid_step:
			# Store the Global Coordinate
			path.append(best_next_pos - offset)
			current_pixel = best_next_pos
			
			# Stop if we are back near the start (Loop closed)
			if i > 10 and current_pixel.distance_to(start_pos + offset) < step_size:
				print("Track Loop Detected!")
				break
		else:
			print("Pathfinding hit a dead end at step ", i)
			break
			
	return path
