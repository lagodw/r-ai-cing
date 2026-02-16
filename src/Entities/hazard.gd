class_name Hazard
extends Area2D

var damage: int = 0
var shooter_id: String = ""
var duration: float = 5.0

# Dimensions
var length: float = 40.0
var width: float = 40.0

# Lobbing / Movement variables
var is_active: bool = false
var lob_speed: float = 800.0

# New Movement Logic
var travel_dir: Vector2 = Vector2.ZERO
var max_travel_dist: float = 0.0
var distance_traveled: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_hit)
	
	# Apply dynamic size
	_apply_dimensions()
	
	# If we have a direction and distance, we are lobbing. Otherwise active.
	if max_travel_dist > 0 and travel_dir != Vector2.ZERO:
		is_active = false
	else:
		_activate()

func _apply_dimensions():
	var sprite = get_node_or_null("Sprite2D")
	if sprite and sprite.texture:
		var tex_size = sprite.texture.get_size()
		# Avoid division by zero
		if tex_size.x > 0 and tex_size.y > 0:
			sprite.scale = Vector2(length / tex_size.x, width / tex_size.y)
	
	var col = get_node_or_null("CollisionShape2D")
	if col:
		# Duplicate shape to avoid resizing ALL hazards when one resizes
		col.shape = col.shape.duplicate()
		
		if col.shape is RectangleShape2D:
			col.shape.size = Vector2(length, width)
		elif col.shape is CircleShape2D:
			# Approximate radius based on the larger dimension
			col.shape.radius = max(length, width) / 2.0

func _physics_process(delta: float) -> void:
	if not is_active:
		var step_dist = lob_speed * delta
		
		# --- Bounce Logic ---
		# Check ahead for walls
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(global_position, global_position + (travel_dir * step_dist * 2.0))
		query.collide_with_areas = false
		query.collide_with_bodies = true
		
		var result = space_state.intersect_ray(query)
		if result and result.collider is StaticBody2D:
			# Bounce!
			var normal = result.normal
			travel_dir = travel_dir.bounce(normal)
			# Nudge slightly to prevent sticking?
		# --------------------

		global_position += travel_dir * step_dist
		distance_traveled += step_dist
		
		# Check arrival
		if distance_traveled >= max_travel_dist:
			_activate()

func _activate() -> void:
	is_active = true
	if duration > 0:
		await get_tree().create_timer(duration).timeout
		_destroy()

func _on_hit(body: Node) -> void:
	if not is_active:
		return

	# Prevent hitting yourself immediately if needed (optional)
	# if body.name == shooter_id: return
		
	if body.has_method("take_damage"):
		# FIX: Only the Server Authority triggers the damage RPC
		if is_multiplayer_authority():
			body.rpc_id(body.get_multiplayer_authority(), "take_damage", damage)
		
		_destroy()

func _destroy():
	if is_multiplayer_authority():
		# Server: Actually delete it, syncing the deletion to clients
		queue_free()
	else:
		# Client: Hide immediately so it feels responsive
		visible = false
		set_physics_process(false)
		if has_node("CollisionShape2D"):
			$CollisionShape2D.set_deferred("disabled", true)
		# We wait for the Server to actually delete us
