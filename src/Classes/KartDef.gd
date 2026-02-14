class_name KartDef extends Resource

@export var id: String

# Stats
@export var max_health: int = 100
@export var max_speed: float = 500.0
@export var acceleration: float = 500.0
@export var traction: float = 10.0:
	set(val):
		traction = clamp(val, 5.0, 20.0)
@export var width_percent: float = 0.2
