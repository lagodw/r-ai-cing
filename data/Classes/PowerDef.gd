class_name PowerDef extends Resource

@export var id: String
@export var type: String # "projectile", "self_buff", "hazard"
@export var sprite_path: String

# Projectile Stats
@export var speed: float = 800.0
@export var damage: int = 10

# Effect Stats (Buffs/Debuffs)
@export var stat_target: String # "max_speed", "health"
@export var amount: float = 0.0
@export var duration: float = 0.0
