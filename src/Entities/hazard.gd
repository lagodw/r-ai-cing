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
var target_pos: Vector2 = Vector2.ZERO
var lob_speed: float = 800.0

func _ready() -> void:
	body_entered.connect(_on_hit)
	
	# Apply dynamic size
	_apply_dimensions()
	
	if target_pos != Vector2.ZERO:
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
		var dir = (target_pos - global_position).normalized()
		var motion = dir * lob_speed * delta
		
		global_position += motion
		
		# Check walls or arrival
		if global_position.distance_to(target_pos) < 10.0:
			_activate()

func _activate() -> void:
	is_active = true
	if duration > 0:
		await get_tree().create_timer(duration).timeout
		queue_free()

func _on_hit(body: Node) -> void:
	if not is_active:
		if body is StaticBody2D: # Hit a wall while lobbing
			_activate()
		return

	#if body.name == shooter_id:
		#return
		
	if body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
