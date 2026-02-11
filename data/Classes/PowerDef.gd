class_name PowerDef extends Resource

@export var id: String
@export_enum("projectile", "buff", "hazard") var type: String
@export var cooldown: float

# Projectile Stats
@export var speed: float = 800.0
@export var damage: int = 10

# Effect Stats (Buffs/Debuffs)
@export_enum("max_speed", "health") var stat_target: String
@export var amount: float = 0.0
@export var duration: float = 0.0
