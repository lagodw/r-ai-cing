extends Node2D

@export var kart_scene: PackedScene = preload("res://src/Entities/Kart.tscn")

@onready var background = $Background
@onready var walls = $Walls
@onready var camera = $Camera2D

func _ready():
	_generate_track_visuals()
	
	# 1. Instantiate Selection Screen
	var selection = load("res://src/World/selection.tscn").instantiate()
	# Add it to the CanvasLayer (Track.tscn doesn't have one, so we add it as child)
	# Since Selection is a CanvasLayer, it will render on top.
	add_child(selection)
	
	# 2. Wait for player to finish selecting
	await selection.race_started
	
	# 3. NOW we spawn everyone
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
	
	# --- Grid Calculation Setup (Same as before) ---
	var raw_start = Vector2(200, 200) 
	var forward_dir = Vector2.RIGHT
	
	if track: 
		raw_start = track.start_position
		if track.waypoints.size() > 1:
			var p0 = track.waypoints[0]
			var p1 = track.waypoints[1]
			forward_dir = (p1 - p0).normalized()
	
	var right_dir = forward_dir.rotated(PI / 2)
	var final_start = raw_start * walls.scale
	
	# --- PREPARE RACER LIST ---
	var racer_configs = []
	
	# 1. Player (Index 0)
	racer_configs.append({
		"id": GameData.selected_kart_id,
		"is_player": true,
		"powers": GameData.selected_powers
	})
	
	# 2. Bots (Indices 1-7)
	var all_kart_ids = GameData.karts.keys()
	for i in range(1):
		racer_configs.append({
			"id": all_kart_ids.pick_random(),
			"is_player": false,
			"powers": [] # Bots have no powers for now
		})
	
	# --- SPAWN LOOP ---
	# Calculate spacing constants
	var max_len = 40.0
	var max_wid = 20.0
	# (Assuming standard size, or you can loop configs to find max)
	
	var gap_depth = max_len * 2.5 # Spacing
	var gap_width = max_wid * 2.0 
	
	for i in range(racer_configs.size()):
		var config = racer_configs[i]
		var kart = kart_scene.instantiate()
		
		# Grid Position Logic
		var lane_index = i % 2 
		var dist_back = float(i) * (gap_depth * 0.5)
		var lane_offset = (float(lane_index) - 0.5) * gap_width
		var grid_offset = (-forward_dir * dist_back) + (right_dir * lane_offset)
		var final_offset = grid_offset * walls.scale
		
		kart.scale = walls.scale
		kart.global_position = final_start + final_offset
		kart.rotation = forward_dir.angle()
		
		# Configure Kart
		kart.kart_id = config.id
		
		if config.is_player:
			kart.name = "1" # Authority
			kart.is_player_controlled = true
			kart.power_inventory = config.powers.duplicate() # Inject selected powers
			
			camera.position = kart.position
			var remote = RemoteTransform2D.new()
			remote.remote_path = camera.get_path()
			kart.add_child(remote)
		else:
			kart.name = "Bot_" + str(i)
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
