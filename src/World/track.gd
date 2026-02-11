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
		background.texture = tex
		
		# 1. IMPORTANT: Align coordinates
		# BitMap generation starts at 0,0 (Top-Left). 
		# Sprites usually default to Center. We must un-center to match.
		#background.centered = false 
		
		# 2. Generate Walls
		if track.walls.is_empty():
			TrackBuilder.generate_walls_from_texture(tex, walls, true)
		else:
			for poly_points in track.walls:
				var col = CollisionPolygon2D.new()
				col.polygon = poly_points
				walls.add_child(col)
				
		# 3. Fit everything to the screen
		_fit_track_to_screen(tex.get_size())

func _fit_track_to_screen(image_size: Vector2):
	# Get the game's resolution (project settings)
	var screen_size = get_viewport_rect().size
	
	# Calculate how much we need to shrink/grow the image to fit
	var scale_factor = Vector2.ONE
	
	# Option A: Stretch to fill (might distort aspect ratio)
	scale_factor = screen_size / image_size
	
	# Option B: Fit to screen (maintain aspect ratio) - RECOMMENDED
	var aspect = min(screen_size.x / image_size.x, screen_size.y / image_size.y)
	scale_factor = Vector2(aspect, aspect)
	
	# Apply scale to Visuals
	background.scale = scale_factor
	
	# Apply scale to Physics (Matches the visual perfectly)
	walls.scale = scale_factor

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
		var offset = Vector2(col * 80, row * 80) * walls.scale # Scale spacing too
		
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
