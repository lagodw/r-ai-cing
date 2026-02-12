extends Node2D

@export var kart_scene: PackedScene = preload("res://src/Entities/Kart.tscn")

@onready var background = $Background
@onready var walls = $Walls
@onready var camera = $Camera2D

func _ready():
	_generate_track_visuals()
	# We spawn racers AFTER the track is scaled so they spawn in the right spot
	_spawn_racers()

func _generate_track_visuals():
	var track = GameData.current_track
	if not track: return
	
	if ResourceLoader.exists(track.background_path):
		var tex = load(track.background_path)
	
		# 1. Generate Walls (Red Outline)
		TrackBuilder.generate_walls_from_texture(tex, walls, true)
		
		# 2. Generate Path (Auto-Walk)
		await get_tree().physics_frame
		await get_tree().physics_frame 

	# Now generate path
		var auto_path = TrackBuilder.generate_path_automatically(self, track.start_position)
		track.waypoints = auto_path
		
		# Draw path for debug (optional)
		queue_redraw()
				
		# 3. Fit everything to the screen
		#_fit_track_to_screen(tex.get_size())

func _fit_track_to_screen(_image_size: Vector2):
	pass
	# Get the game's resolution (project settings)
	#var screen_size = get_viewport_rect().size
	
	# Calculate how much we need to shrink/grow the image to fit
	#var scale_factor = Vector2.ONE
	
	# Option A: Stretch to fill (might distort aspect ratio)
	#scale_factor = screen_size / image_size
	
	# Option B: Fit to screen (maintain aspect ratio) - RECOMMENDED
	#var aspect = min(screen_size.x / image_size.x, screen_size.y / image_size.y)
	#scale_factor = Vector2(aspect, aspect)
	
	# Apply scale to Visuals
	#background.scale = scale_factor
	
	# Apply scale to Physics (Matches the visual perfectly)
	#walls.scale = scale_factor

func _spawn_racers():
	var track = GameData.current_track
	
	# 1. Determine Start Position and Orientation
	var raw_start = Vector2(200, 200) 
	var forward_dir = Vector2.RIGHT # Default to pointing Right
	
	if track: 
		raw_start = track.start_position
		# Auto-detect direction based on the first two waypoints
		if track.waypoints.size() > 1:
			var p0 = track.waypoints[0]
			var p1 = track.waypoints[1]
			forward_dir = (p1 - p0).normalized()
	
	# Calculate the "Right" vector (90 degrees from forward) for lane spacing
	var right_dir = forward_dir.rotated(PI / 2)
	
	var final_start = raw_start * walls.scale
	var all_kart_ids = GameData.karts.keys()
	
	# 2. Analyze Kart Sizes for Dynamic Spacing
	var max_len = 40.0
	var max_wid = 20.0
	
	for id in all_kart_ids:
		var stats = GameData.karts.get(id)
		if stats:
			if stats.length > max_len: max_len = stats.length
			if stats.width > max_wid: max_wid = stats.width
			
	# Grid Configuration
	# "gap_depth": Distance between a kart and the one directly behind it (in the same lane)
	# We use 1.5x length for safety.
	var gap_depth = max_len * 1.25 
	var gap_width = max_wid * 0.5 # Good spacing between parallel lanes
	
	for i in range(all_kart_ids.size()):
		var id = all_kart_ids[i]
		var kart = kart_scene.instantiate()
		
		# 3. Calculate Staggered Position
		var lane_index = i % 2 # 0 or 1
		
		# "Half offset in columns":
		# We step back by 0.5 * gap_depth for every single kart. 
		# This puts Kart 2 exactly one full gap_depth behind Kart 0.
		var dist_back = float(i) * (gap_depth * 0.5)
		
		# Center the two lanes around the start line
		# Lane 0 goes Left (-0.5 width), Lane 1 goes Right (+0.5 width)
		var lane_offset = (float(lane_index) - 0.5) * gap_width
		
		# Combine vectors: Start - Backward + Sideways
		# We multiply by walls.scale to ensure the grid matches the zoom level
		var grid_offset = (-forward_dir * dist_back) + (right_dir * lane_offset)
		var final_offset = grid_offset * walls.scale
		
		kart.scale = walls.scale
		kart.global_position = final_start + final_offset
		
		# Align kart to face the race direction
		kart.rotation = forward_dir.angle()
		
		# --- Setup (Unchanged) ---
		if i == 0:
			kart.name = "1"
			kart.kart_id = id
			kart.is_player_controlled = true
			
			camera.position = kart.position
			var remote = RemoteTransform2D.new()
			remote.remote_path = camera.get_path()
			kart.add_child(remote)
		else:
			kart.name = "Bot_" + str(i)
			kart.kart_id = id
			kart.is_player_controlled = false
			var brain = load("res://src/Entities/AIController.gd").new()
			brain.name = "AIController"
			kart.add_child(brain)
			
		add_child(kart)
#
#func _draw():
	#var track = GameData.current_track
	#if not track or track.waypoints.is_empty():
		#return
#
	#var points = track.waypoints
	#var num_points = points.size()
	#
	## We must use the same scaling as the walls/background
	#var s = walls.scale 
#
	#for i in range(num_points):
		#var current_p = points[i] * s
		#var next_p = points[(i + 1) % num_points] * s # Wrap around for loop
		#
		## Draw a line to the next waypoint
		#draw_line(current_p, next_p, Color.CYAN, 4.0)
		#
		## Draw a circle at the waypoint
		## Index 0 is GREEN (Start), others are BLUE
		#var color = Color.GREEN if i == 0 else Color.BLUE
		#draw_circle(current_p, 10.0, color)
