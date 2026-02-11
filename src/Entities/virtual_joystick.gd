class_name VirtualJoystick
extends Control

# Configuration
@onready var base = $Base
@onready var handle = $Base/Handle
var max_distance = 75.0 # Pixels (Radius of the base)

# State
var touch_index = -1
var is_active = false

func get_output() -> Vector2:
	# Returns a normalized Vector2 (-1 to 1)
	var center = base.size / 2
	var offset = handle.position + (handle.size / 2) - center
	return offset / max_distance

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			# Check if touch started inside our control area
			if get_global_rect().has_point(event.position):
				touch_index = event.index
				is_active = true
				_update_handle(event.position)
		elif not event.pressed and event.index == touch_index:
			_reset()
	
	elif event is InputEventScreenDrag and event.index == touch_index:
		_update_handle(event.position)

func _update_handle(screen_pos):
	var local_pos = base.get_global_transform().affine_inverse() * screen_pos
	var center = base.size / 2
	var vector = local_pos - center
	
	# Clamp the handle inside the base circle
	if vector.length() > max_distance:
		vector = vector.normalized() * max_distance
	
	handle.position = center + vector - (handle.size / 2)

func _reset():
	touch_index = -1
	is_active = false
	handle.position = (base.size / 2) - (handle.size / 2) # Center it
