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
	# Start Position also needs to be scaled!
	var raw_start = Vector2(200, 200) 
	if track: raw_start = track.start_position
	
	# Apply the same scale to the spawn point
	var final_start = raw_start * walls.scale
	
	var all_kart_ids = GameData.karts.keys()
	
	for i in range(all_kart_ids.size()):
		var id = all_kart_ids[i]
		var kart = kart_scene.instantiate()
		
		# Grid positioning (scaled)
		var col = i % 2
		var row = float(i) / 2
		var offset = Vector2(col * 20, row * 20) * walls.scale # Scale spacing too
		
		kart.scale = walls.scale
		kart.global_position = final_start + offset
		
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
