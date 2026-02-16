extends Node

#signal connection_failed
signal connection_succeeded
signal game_started # Signal to tell UI to switch to the game scene
signal player_list_updated # Signal to update the lobby UI list
signal game_started_with_loadouts

var peer = WebSocketMultiplayerPeer.new()
const PORT = 8080
const LIVE_SERVER_URL = "wss://r-ai-cing.onrender.com"
const LOCAL_SERVER_URL = "ws://127.0.0.1:8080"
const IS_PROD_BUILD = true 

# --- Lobby Variables ---
var room_code = ""
var players = {} # Dictionary: { peer_id: { "name": "Player1", "room": "ABCD" } }
# Dictionary to store what kart/power each player chose
# Format: { player_id: { "kart": "speedster", "power": "missile", "name": "Bob" } }
var player_loadouts = {}
var completed_room_loadouts = {}

func _ready():
	if "--server" in OS.get_cmdline_args() or OS.has_feature("dedicated_server"):
		_start_server()

func join_server():
	# 1. Reset the peer if it was stuck connecting or failed
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		peer.close()
	
	# 2. Determine URL
	var target_url = LIVE_SERVER_URL if IS_PROD_BUILD else LOCAL_SERVER_URL
	
	# 3. Create Client
	var error = peer.create_client(target_url)
	if error != OK:
		printerr("Client creation failed: ", error)
		return
	
	# 4. Assign peer to multiplayer API
	multiplayer.multiplayer_peer = peer
	
	# 5. Connect signals safely (prevent duplicates)
	if not multiplayer.connected_to_server.is_connected(_on_connection_success):
		multiplayer.connected_to_server.connect(_on_connection_success)


func _start_server():
	GameData.is_singleplayer = false
	var port = int(OS.get_environment("PORT")) if OS.get_environment("PORT") != "" else PORT
	peer.create_server(port, "0.0.0.0")
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Server listening on " + str(port))

# --- LOBBY SYSTEM (New Stuff) ---

# Called by UI when player clicks "Host Game"
func request_create_room(player_name):
	# Generate a random 4-letter code locally
	var code = ""
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	for i in range(4):
		code += chars[randi() % chars.length()]
	
	# Tell the server we want to join this room
	rpc_id(1, "register_player", player_name, code)

# Called by UI when player clicks "Join Game" with a code
func request_join_room(player_name, code):
	# Tell the server we want to join this specific room
	rpc_id(1, "register_player", player_name, code.to_upper())

@rpc("any_peer")
func register_player(player_name, code):
	var id = multiplayer.get_remote_sender_id()
	
	# If this is the Server, store the info
	if multiplayer.is_server():
		players[id] = { "name": player_name, "room": code }
		# Sync this list to everyone
		rpc("update_player_list", players)
		print("Player " + str(id) + " joined room " + code)

@rpc("authority", "call_local")
func update_player_list(new_players):
	# 1. CLEANUP: Force all keys to be Integers
	# This fixes the "String Key" bug if it occurs
	players = {}
	for key in new_players:
		var int_key = int(str(key)) # Convert "123" -> 123
		players[int_key] = new_players[key]

	# 2. UPDATE LOCAL ROOM
	var my_id = multiplayer.get_unique_id()
	if my_id in players:
		room_code = players[my_id]["room"]
	
	emit_signal("player_list_updated")

# --- Standard boilerplate ---
func _on_connection_success(): emit_signal("connection_succeeded")
func _on_peer_connected(_id): pass # We handle this in register_player now
func _on_peer_disconnected(id):
	if multiplayer.is_server():
		print("Peer disconnected: ", id)
		players.erase(id)
		player_loadouts.erase(id) # Clean up their loadout data
		rpc("update_player_list", players)
		
		# If the server is now empty, reset it to prevent getting stuck
		if players.is_empty():
			_reset_server_state()
			
func _reset_server_state():
	print("All players disconnected. Resetting server state...")
	
	# 1. Clear Data
	room_code = ""
	players.clear()
	player_loadouts.clear()
	completed_room_loadouts.clear()
	
	# 2. Reset Scene
	# We move the server back to the main menu (or a simple empty scene)
	# to stop the game physics/logic from running unnecessarily.
	# We use call_deferred to safely change scenes during a callback.
	get_tree().call_deferred("change_scene_to_file", "res://src/World/main_menu.tscn")

# 1. Client calls this when clicking "Start"
func request_start_game():
	# Verify we are actually in a room
	if room_code == "": return
	
	print("Requesting server to start game for Room: ", room_code)
	# Tell the Server (ID 1) to start the game for our room
	rpc_id(1, "server_handle_start_game", room_code)

# 2. Server runs this to process the request
@rpc("any_peer")
func server_handle_start_game(code):
	# 1. Clear old data for this room
	completed_room_loadouts.erase(code)
	
	# 2. Select Track
	var track_keys = GameData.tracks.keys()
	var selected_track_id = track_keys.pick_random()
	if selected_track_id in GameData.tracks:
		GameData.current_track = GameData.tracks[selected_track_id]
	
	# 3. Force Full Scene Reload
	# We use change_scene_to_file even if we are already in Track.tscn.
	# This ensures a complete teardown of the old scene and a fresh start for Physics/TrackBuilder.
	get_tree().change_scene_to_file("res://src/World/Track.tscn")
	
	# 4. Notify Clients
	for p_id in players:
		if players[p_id]["room"] == code:
			rpc_id(p_id, "client_begin_game", selected_track_id)

# 3. Client receives this and actually switches scenes
@rpc("authority")
func client_begin_game(track_id: String):
	print("Game Start signal received from Server! Map: ", track_id)
	
	if track_id in GameData.tracks:
		GameData.current_track = GameData.tracks[track_id]
	else:
		printerr("Server sent unknown track ID: ", track_id)
	
	emit_signal("game_started")
# 1. Client sends their choice to the server
func send_player_selection(kart_id: String, power_ids: Array):
	rpc_id(1, "server_receive_selection", kart_id, power_ids)

# 2. Server stores it and checks if everyone is ready
@rpc("any_peer")
func server_receive_selection(kart_id: String, power_ids: Array):
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Store the loadout
	if sender_id in players:
		player_loadouts[sender_id] = {
			"name": players[sender_id]["name"],
			"kart": kart_id,
			"powers": power_ids,
			"room": players[sender_id]["room"]
		}
	
	print("Player ", sender_id, " is ready with ", kart_id)
	
	# CHECK: Are all players in this room ready?
	var player_room_code = players[sender_id]["room"]
	if _are_all_players_ready(player_room_code):
		print("All players in room ", player_room_code, " are ready! Starting race...")
		
		# Get only the loadouts for this room
		var room_loadouts = {}
		for id in player_loadouts:
			if player_loadouts[id]["room"] == player_room_code:
				room_loadouts[id] = player_loadouts[id]
				
		# 1. Tell clients to start
		rpc_to_room(player_room_code, "client_start_race", room_loadouts)
		
		# 2. NEW: Tell the Server (Self) to start
		# The server instance needs this signal to trigger _spawn_racers in track.gd
		emit_signal("game_started_with_loadouts", room_loadouts)

# Helper function to check readiness
func _are_all_players_ready(player_room_code):
	for id in players:
		if players[id]["room"] == player_room_code:
			if not id in player_loadouts:
				return false # This person hasn't chosen yet
	return true

# 3. Client receives the full list and starts
@rpc("authority")
func client_start_race(all_loadouts):
	# We emit a signal with the data so track.gd can use it
	emit_signal("game_started_with_loadouts", all_loadouts)
	
# Helper to send RPC only to people in a specific room
func rpc_to_room(player_room_code, function_name, data):
	for id in players:
		if players[id]["room"] == player_room_code:
			rpc_id(id, function_name, data)

# Call this from Track.gd when the game ends (Server side only)
func reset_server_to_main_menu():
	if not multiplayer.is_server(): return
	
	print("Game finished. Resetting Server to Main Menu...")
	
	# 1. Clear Game State so new games can start fresh
	player_loadouts.clear() 
	
	# 2. Reset the Server's scene ONLY. 
	# Connected clients will stay in the Track scene until they manually leave.
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/World/main_menu.tscn")
