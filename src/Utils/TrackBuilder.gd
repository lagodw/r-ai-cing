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
