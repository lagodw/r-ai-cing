extends Node2D

@export var kart_scene: PackedScene = preload("res://src/Entities/Kart.tscn")

@onready var background = $Background
@onready var walls = $Walls
@onready var camera = $Camera2D
@onready var multiplayer_spawner = $MultiplayerSpawner
@onready var ui_layer = $UI

func _ready():
	$Victory/Panel/VBoxContainer/Again.pressed.connect(go_again)
	$Victory/Panel/VBoxContainer/Main.pressed.connect(main_menu)
	multiplayer_spawner.spawn_function = _spawn_kart_custom
	
	# --- NEW SERVER CHECK ---
	# If we are the Dedicated Server (ID 1) AND NOT playing locally (headless/render):
	if multiplayer.is_server() and not GameData.is_singleplayer:
		print("Server loaded Track. Waiting for loadouts...")
		# The server skips UI and just waits for the signal from MultiplayerManager
		var all_loadouts = await MultiplayerManager.game_started_with_loadouts
		
		# Generate visuals (needed for collision walls)
		_generate_track_visuals()
		
		# Spawn the racers (Server is the only one who can do this via Spawner)
		_spawn_racers(all_loadouts)
		return
	# ------------------------
	
	# --- CLIENT LOGIC (Original) ---
	# 1. Instantiate Selection Screen
	var selection = load("res://src/World/selection.tscn").instantiate()
	ui_layer.add_child(selection)
	
	# 2. Wait for player to finish selecting locally
	await selection.race_started
	
	# --- MULTIPLAYER HANDSHAKE ---
	if not GameData.is_singleplayer:
		$MultiplayerWaiting.visible = true
		
		# A. Convert Power Objects to IDs for network transmission
		var power_ids = []
		for p in GameData.selected_powers:
			power_ids.append(p.id)
			
		# B. Send selection to server
		MultiplayerManager.send_player_selection(GameData.selected_kart_id, power_ids)
		
		# C. Wait for Server to say "Everyone is ready"
		var all_loadouts = await MultiplayerManager.game_started_with_loadouts
		
		# D. Clients generate visuals but DO NOT spawn karts (Spawner handles it)
		_generate_track_visuals()
		_spawn_racers(all_loadouts) 
		
		$MultiplayerWaiting.visible = false
		start_countdown()
	else:
		# --- SINGLE PLAYER FLOW ---
		_generate_track_visuals()
		_spawn_racers(null)
		start_countdown()
	
func start_game():
	get_tree().paused = true
	# 3. NOW we spawn everyone
	_spawn_racers()
	start_countdown()

func _generate_track_visuals():
	var track = GameData.current_track
	if not track: return
	
	var path = "res://assets/tracks/%s.png"%track.id
	if ResourceLoader.exists(path):
		var tex = load(path)
		background.texture = tex
		await get_tree().process_frame
	
		# 1. Generate Walls
		TrackBuilder.generate_walls_from_texture(tex, walls, true)
		
		var detected_start = TrackBuilder.find_start_position_from_texture(tex, true)
		if detected_start != Vector2.INF:
			track.start_position = detected_start
		
		# Wait for Physics
		await get_tree().physics_frame
		await get_tree().physics_frame 

		# 2. Generate Path AND Get Angle (UPDATED)
		var result = TrackBuilder.generate_path_automatically(self, track.start_position)
		
		track.waypoints = result["path"]
		track.start_angle = result["angle"] # Store the angle
		
		# 3. Measure Width using the angle we just found (NEW)
		track.track_width = TrackBuilder.measure_track_width(self, track.start_position, track.start_angle)
		
		queue_redraw()
	
	#start_game()

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
	kart.race_finished.connect(winner_screen)
	
	return kart

func _spawn_racers(mp_loadouts = null):
	var track = GameData.current_track
	
	# --- Grid Calculation Setup ---
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
	
	# --- PREPARE DATA LIST (Same as before) ---
	var racer_configs = []
	
	if GameData.is_singleplayer:
		# ... (Single Player Config Logic - Same as previous turn) ...
		# See "Single Player Logic" block below for refresher if needed
		racer_configs.append({ "id": GameData.selected_kart_id, "is_player": true, "name": "1", "powers": GameData.selected_powers, "peer_id": 1 })
		# (Add bots logic here if needed...)
	else:
		# Multiplayer Logic
		for peer_id in mp_loadouts:
			var data = mp_loadouts[peer_id]
			# Convert powers to actual objects or keep IDs? 
			# For the CONFIG list, let's keep them as objects or IDs.
			# But for the SPAWNER, we need IDs.
			racer_configs.append({
				"id": data["kart"],
				"is_player": true, # In MP, everyone in the list is a player
				"name": str(peer_id),
				"power_ids": data["powers"], # These are already IDs from MPManager
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
			"power_ids": [] 
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
#
func _draw():
	var track = GameData.current_track
	if not track or track.waypoints.is_empty():
		return

	var points = track.waypoints
	var num_points = points.size()
	
	# We must use the same scaling as the walls/background
	var s = walls.scale 

	for i in range(num_points):
		var current_p = points[i] * s
		var next_p = points[(i + 1) % num_points] * s # Wrap around for loop
		
		# Draw a line to the next waypoint
		draw_line(current_p, next_p, Color.CYAN, 4.0)
		
		# Draw a circle at the waypoint
		# Index 0 is GREEN (Start), others are BLUE
		var color = Color.GREEN if i == 0 else Color.BLUE
		draw_circle(current_p, 10.0, color)

func winner_screen(winner_name: String):
	if winner_name == "1":
		$Victory/Panel/Winner.text = "You!"
	else:
		$Victory/Panel/Winner.text = winner_name
	$Victory.visible = true
	get_tree().paused = true

func go_again():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/World/Track.tscn")
	
func main_menu():
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
	
