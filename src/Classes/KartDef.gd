class_name KartDef extends Resource

@export var id: String

# Stats
@export var max_health: int = 100
@export var max_speed: float = 500.0
@export var acceleration: float = 800.0
@export var turn_speed: float = 3.5
@export var length: float = 80.0
@export var width: float = 40.0
## Where projectiles spawn
@export var weapon_offset: Vector2 = Vector2.ZERO
