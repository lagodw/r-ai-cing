class_name Projectile
extends Area2D

var speed = 0
var damage = 0
var shooter_id = 0 # To prevent shooting yourself

func _ready():
	connect("body_entered", _on_hit)

func _physics_process(delta):
	position += Vector2.RIGHT.rotated(rotation) * speed * delta

func _on_hit(body):
	# Don't hit the shooter
	if body.name == str(shooter_id): return
	
	# Don't hit walls (just destroy bullet)
	if not body.has_method("take_damage"):
		queue_free()
		return

	# Deal Damage
	body.take_damage(damage)
	queue_free()
