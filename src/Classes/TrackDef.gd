class_name TrackDef extends Resource

@export var id: String
@export var laps_required: int = 3
@export var start_position: Vector2
@export var waypoints: PackedVector2Array # Optimized array for vector math
@export var walls: Array[PackedVector2Array] # Array of polygons
@export var hazards: Array[Dictionary] # Keep simple for now
