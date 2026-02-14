class_name TrackDef extends Resource

@export var id: String
@export var laps_required: int = 3
@export var start_position: Vector2
@export var start_angle: float = 0.0
@export var track_width: float = 200.0
@export var waypoints: PackedVector2Array 
@export var walls: Array[PackedVector2Array] 
@export var hazards: Array[Dictionary]
