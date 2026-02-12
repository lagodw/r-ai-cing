class_name PowerDef extends Resource

@export var id: String
@export_enum("Projectile", "Buff", "Hazard") var type: String
@export var cooldown: float
@export var length: float = 20.0
@export var width: float = 20.0

# Projectile Stats
@export var speed: float = 800.0
@export var damage: int = 10
@export_enum("Forward", "Backward", "Homing", "Orbit") var projectile_behavior: String = "Forward"
## For Homing: How fast it steers (radians/sec)
@export var turn_speed: float = 4.0
## For Homing: How far it sees
@export var detection_radius: float = 400.0

# Effect Stats (Buffs/Debuffs)
@export_enum("max_speed", "health") var stat_target: String
@export var amount: float = 0.0
## Used for Buff duration OR Orbit duration
@export var duration: float = 0.0
