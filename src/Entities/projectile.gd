class_name Projectile
extends Area2D

# Config
var speed = 0
var damage = 0
var shooter_id = 0
var behavior: String = "straight"

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

func _ready():
	connect("body_entered", _on_hit)
	
	# Apply dynamic size
	_apply_dimensions()
	
	if behavior == "orbit" and orbit_center:
		orbit_angle = global_position.angle_to_point(orbit_center.global_position)

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
	match behavior:
		"orbit":
			_process_orbit(delta)
		"homing":
			_process_homing(delta)
			_move_forward(delta)
		_:
			_move_forward(delta)

func _move_forward(delta):
	position += Vector2.RIGHT.rotated(rotation) * speed * delta

func _process_orbit(delta):
	orbit_timer += delta
	if orbit_timer > orbit_duration:
		queue_free()
		return

	if not is_instance_valid(orbit_center):
		queue_free()
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
	
	if not body.has_method("take_damage") and behavior != "orbit":
		queue_free()
		return

	if body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
