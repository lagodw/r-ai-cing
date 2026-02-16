extends Node2D

@export var kart_scene: PackedScene = preload("res://src/Entities/Kart.tscn")

@onready var background = $Background
@onready var walls = $Walls
@onready var camera = $Camera2D
@onready var ui_layer = $UI
@onready var multiplayer_spawner = $MultiplayerSpawner
@onready var projectile_spawner = $ProjectileSpawner
@onready var hazard_spawner = $HazardSpawner

func _ready():
	if not GameData.is_singleplayer:
		$Victory/Panel/VBoxContainer/Again.visible = false
	$Victory/Panel/VBoxContainer/Again.pressed.connect(go_again)
	$Victory/Panel/VBoxContainer/Main.pressed.connect(main_menu)
	multiplayer_spawner.spawn_function = _spawn_kart_custom
	projectile_spawner.spawn_function = _spawn_projectile_custom
	hazard_spawner.spawn_function = _spawn_hazard_custom
	
	# --- SERVER LOGIC ---
	if multiplayer.is_server() and not GameData.is_singleplayer:
		print("Server loaded Track. Waiting for loadouts...")
		var all_loadouts = await MultiplayerManager.game_started_with_loadouts
		
		# FIX: Calculate track data (Start Pos, Waypoints) BEFORE spawning
		await _initialize_track_data() 
		
		# Server doesn't need to draw sprites to know physics, 
		# but _initialize_track_data handles the logic.
		# If you want visuals on server for debug, you can call _generate_visuals too.
		_generate_track_visuals() 
		
		_spawn_racers(all_loadouts)
		return

	# --- CLIENT LOGIC ---
	var selection = load("res://src/World/selection.tscn").instantiate()
	ui_layer.add_child(selection)
	
	await selection.race_started
	
	if not GameData.is_singleplayer:
		$MultiplayerWaiting.visible = true
		
		var power_ids = []
		for p in GameData.selected_powers:
			power_ids.append(p.id)
			
		MultiplayerManager.send_player_selection(GameData.selected_kart_id, power_ids)
		
		var _all_loadouts = await MultiplayerManager.game_started_with_loadouts
		
		# FIX: Client also calculates data to ensure sync (and for visuals)
		await _initialize_track_data()
		_generate_track_visuals()
		
		# Client doesn't spawn (Spawner does), but needs to know track data for camera/prediction
		
		$MultiplayerWaiting.visible = false
		start_countdown()
	else:
		# Singleplayer
		await _initialize_track_data()
		_generate_track_visuals()
		_spawn_racers(null)
		start_countdown()
	
func start_game():
	get_tree().paused = true
	# 3. NOW we spawn everyone
	_spawn_racers()
	start_countdown()

func _initialize_track_data():
	var track = GameData.current_track
	if not track: return
	
	var path = "res://assets/tracks/%s.png" % track.id
	if ResourceLoader.exists(path):
		var tex = load(path)
		
		# 1. Setup Walls (Needed for Physics Raycasts)
		# We must do this first so raycasts in TrackBuilder work
		TrackBuilder.generate_walls_from_texture(tex, walls, true)
		
		# Wait for physics to update so walls are "real"
		await get_tree().physics_frame
		await get_tree().physics_frame 
		
		# 2. Find Start Position
		var detected_start = TrackBuilder.find_start_position_from_texture(tex, true)
		if detected_start != Vector2.INF:
			track.start_position = detected_start
		else:
			print("WARNING: No start position found (Magenta pixel). Defaulting to 0,0")
			track.start_position = Vector2.ZERO
			
		# 3. Generate Waypoints & Width (Requires Walls & Start Pos)
		var result = TrackBuilder.generate_path_automatically(self, track.start_position)
		track.waypoints = result["path"]
		track.start_angle = result["angle"] 
		track.track_width = TrackBuilder.measure_track_width(self, track.start_position, track.start_angle)

func _generate_track_visuals():
	var track = GameData.current_track
	if not track: return
	
	# Visuals only (Texture)
	var path = "res://assets/tracks/%s.png" % track.id
	if ResourceLoader.exists(path):
		var tex = load(path)
		background.texture = tex
		queue_redraw()

# This runs on BOTH Server and Clients to build the exact same node
func _spawn_kart_custom(data: Dictionary) -> Node:
	var kart = kart_scene.instantiate()
	
	# 1. Apply Transform
	kart.global_position = data["position"]
	kart.rotation = data["rotation"]
	kart.scale = data["scale"]
	
	# 2. Set Network Identity
	kart.name = str(data["name"]) 
	kart.set_multiplayer_authority(data["peer_id"])
	kart.player_name = data.get("player_name", "Racer")
	
	# 3. Apply Kart Settings
	kart.kart_id = data["kart_id"]
	kart.track_width_ref = data["track_width"]
	kart.is_player_controlled = data["is_player"]
	
	# 4. Reconstruct Powers
	var reconstructed_powers: Array[PowerDef] = []
	for pid in data["power_ids"]:
		if pid in GameData.powers:
			reconstructed_powers.append(GameData.powers[pid])
	kart.power_inventory = reconstructed_powers
	
	# 5. Setup Local Player Specifics
	# FIX: Check the data directly instead of asking the node (which isn't in tree yet)
	if data["is_player"] and data["peer_id"] == multiplayer.get_unique_id():
		camera.position = kart.position
		var remote = RemoteTransform2D.new()
		remote.remote_path = camera.get_path()
		kart.add_child(remote)
		$UI.setup(kart)
	
	# 6. Signal Connect
	kart.race_finished.connect(_on_race_finished)
	
	return kart

func _spawn_racers(mp_loadouts = null):
	var track = GameData.current_track
	
	# --- Grid Calculation Setup ---
	var raw_start = track.start_position
	var forward_dir = Vector2.RIGHT
	if track: 
		raw_start = track.start_position
		if track.waypoints.size() > 1:
			var p0 = track.waypoints[0]
			var p1 = track.waypoints[1]
			forward_dir = (p1 - p0).normalized()
	var right_dir = forward_dir.rotated(PI / 2)
	var final_start = raw_start * walls.scale
	
	# --- PREPARE DATA LIST (Same as before) ---
	var racer_configs = []
	
	if GameData.is_singleplayer:
		# Singleplayer Config
		racer_configs.append({ 
			"id": GameData.selected_kart_id, 
			"is_player": true, 
			"name": "1", 
			"display_name": "You",
			"powers": GameData.selected_powers, 
			"peer_id": 1 
		})
	else:
		# Multiplayer Logic
		for peer_id in mp_loadouts:
			var data = mp_loadouts[peer_id]
			racer_configs.append({
				"id": data["kart"],
				"is_player": true,
				"name": str(peer_id), # Keep ID for Godot internal networking
				"display_name": data["name"],
				"power_ids": data["powers"],
				"peer_id": peer_id
			})

	# --- SPAWN LOOP ---
	# Constants
	var gap_depth = 40.0 * 2.5
	var gap_width = 20.0 * 2.0 
	
	# IMPORTANT: Only the Server (or Singleplayer) runs the loop to create karts
	if not GameData.is_singleplayer and not multiplayer.is_server():
		return 

	for i in range(racer_configs.size()):
		var config = racer_configs[i]
		
		# Calculate Grid Position
		var lane_index = i % 2 
		var dist_back = float(i) * (gap_depth)
		var lane_offset = (float(lane_index) - 0.5) * gap_width
		var grid_offset = (-forward_dir * dist_back) + (right_dir * lane_offset)
		var final_pos = final_start + (grid_offset * walls.scale)
		var final_rot = forward_dir.angle()
		
		# --- PREPARE DATA FOR SPAWNER ---
		var spawn_data = {
			"position": final_pos,
			"rotation": final_rot,
			"scale": walls.scale,
			"name": config.name,
			"peer_id": config.peer_id,
			"kart_id": config.id,
			"is_player": config.is_player,
			"track_width": track.track_width,
			# Handle power IDs: if config.powers is Objects (SP), convert to IDs. If IDs (MP), use as is.
			"power_ids": [] ,
			"player_name": config.display_name,
		}
		
		if GameData.is_singleplayer:
			for p in config.powers: spawn_data["power_ids"].append(p.id)
			# Singleplayer: Spawn Manually (Spawner often requires MP peer)
			var kart_node = _spawn_kart_custom(spawn_data)
			add_child(kart_node)
		else:
			spawn_data["power_ids"] = config.power_ids
			# Multiplayer: Server calls spawn() -> Replicates to all
			multiplayer_spawner.spawn(spawn_data)

func _spawn_projectile_custom(data: Dictionary) -> Node:
	var proj_scene = load("res://src/Entities/Projectile.tscn")
	var proj = proj_scene.instantiate()
	
	# 1. Apply Transform
	proj.global_position = data["position"]
	proj.rotation = data["rotation"]
	
	# 2. Apply Base Stats
	proj.shooter_id = data["shooter_id"]
	proj.behavior = data["behavior"]
	proj.speed = data["speed"]
	proj.damage = data["damage"]
	proj.length = data["length"]
	proj.width = data["width"]
	
	# 3. Apply Texture
	if data.has("texture_path") and data["texture_path"] != "":
		var sprite = proj.get_node_or_null("Sprite2D")
		if sprite:
			sprite.texture = load(data["texture_path"])
	
	# 4. Apply Advanced Behavior Stats (New)
	if data.has("homing_turn_speed"): proj.homing_turn_speed = data["homing_turn_speed"]
	if data.has("detection_radius"): proj.detection_radius = data["detection_radius"]
	if data.has("can_bounce"): proj.can_bounce = data["can_bounce"]
	if data.has("max_lifetime"): proj.max_lifetime = data["max_lifetime"]
	
	# 5. Orbit Specifics
	if data.has("orbit_center_path"):
		proj.orbit_center = get_node_or_null(data["orbit_center_path"])
	if data.has("orbit_duration"):
		proj.orbit_duration = data["orbit_duration"]
		
	return proj
	
func _spawn_hazard_custom(data: Dictionary) -> Node:
	var hazard_scene = load("res://src/Entities/Hazard.tscn")
	var hazard = hazard_scene.instantiate()
	
	# Apply Transform
	hazard.global_position = data["position"]
	hazard.rotation = data["rotation"]
	
	# Apply Stats
	hazard.shooter_id = data["shooter_id"]
	hazard.damage = data["damage"]
	hazard.duration = data["duration"]
	hazard.length = data["length"]
	hazard.width = data["width"]
	hazard.lob_speed = data["lob_speed"]
	
	# Apply Lobbing/Movement Data
	hazard.travel_dir = data["travel_dir"]
	hazard.max_travel_dist = data["max_travel_dist"]
	
	# Apply Visuals
	if data.has("texture_path"):
		var sprite = hazard.get_node_or_null("Sprite2D")
		if sprite:
			sprite.texture = load(data["texture_path"])
			
	return hazard
	
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

@rpc("any_peer", "call_local", "reliable") 
func winner_screen(winner_name: String):
	# 1. Check if the winner is ME based on name
	var is_me = false
	
	if GameData.is_singleplayer:
		if winner_name == "You": is_me = true
	else:
		# Check against my local name stored in MultiplayerManager
		var my_id = multiplayer.get_unique_id()
		if my_id in MultiplayerManager.players:
			if winner_name == MultiplayerManager.players[my_id]["name"]:
				is_me = true
	
	# 2. Show Text
	if is_me:
		$Victory/Panel/Winner.text = "You!"
	else:
		$Victory/Panel/Winner.text = winner_name + "!"

	$Victory.visible = true
	get_tree().paused = true
	
	# SERVER ONLY: Auto-Reset Logic
	if multiplayer.is_server() and not GameData.is_singleplayer:
		# Wait 5 seconds, then reset server to Main Menu
		# This timer must have 'one_shot' and 'autostart' or be created via code
		var timer = get_tree().create_timer(5.0)
		await timer.timeout
		
		# Server goes home, leaving clients on the victory screen
		MultiplayerManager.reset_server_to_main_menu()

func go_again():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/World/Track.tscn")
	
func main_menu():
	if GameData.is_singleplayer:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://src/World/main_menu.tscn")
		return

	# 1. Close connection (Clean exit)
	multiplayer.multiplayer_peer.close()
	
	# 2. Clear local data
	MultiplayerManager.players.clear()
	MultiplayerManager.room_code = ""
	
	# 3. Go to local main menu
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/World/main_menu.tscn")

func start_countdown():
	$UI.visible = true
	$Start.visible = true
	await get_tree().create_timer(1).timeout
	%Countdown.text = str(2)
	await get_tree().create_timer(1).timeout
	%Countdown.text = str(1)
	await get_tree().create_timer(1).timeout
	%Countdown.text = "Start!"
	await get_tree().create_timer(1).timeout
	$Start.visible = false
	get_tree().paused = false
	
func _on_race_finished(winner_name: String):
	# Only the person who actually won triggers the broadcast
	# (This prevents duplicate calls if we had server-side checks later)
	rpc("winner_screen", winner_name)
