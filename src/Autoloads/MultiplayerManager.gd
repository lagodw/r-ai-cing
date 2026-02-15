extends Node

#signal connection_failed
signal connection_succeeded
signal game_started # Signal to tell UI to switch to the game scene
signal player_list_updated # Signal to update the lobby UI list

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

func _ready():
	if "--server" in OS.get_cmdline_args() or OS.has_feature("dedicated_server"):
		_start_server()

# --- Connection Logic (Keep as is, but simplified for brevity) ---
func join_server():
	# This connects to the "Hotel" (Render), but doesn't join a room yet
	var target_url = LIVE_SERVER_URL if IS_PROD_BUILD else LOCAL_SERVER_URL
	peer.create_client(target_url)
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connection_success)

func _start_server():
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
	else:
		print("ERROR: I am not in the player list!")
	
	emit_signal("player_list_updated")

# --- Standard boilerplate ---
func _on_connection_success(): emit_signal("connection_succeeded")
func _on_peer_connected(_id): pass # We handle this in register_player now
func _on_peer_disconnected(id):
	if multiplayer.is_server():
		players.erase(id)
		rpc("update_player_list", players)

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
	# Only the Server runs this!
	var sender_id = multiplayer.get_remote_sender_id()
	print("Server received Start Request from ", sender_id, " for Room ", code)
	
	# Loop through ALL players on the server
	for p_id in players:
		# Check if this player is in the requested room
		if players[p_id]["room"] == code:
			# Send the "GO!" command specific to this player
			rpc_id(p_id, "client_begin_game")

# 3. Client receives this and actually switches scenes
@rpc("authority")
func client_begin_game():
	print("Game Start signal received from Server!")
	emit_signal("game_started")

# 1. Client sends their choice to the server
func send_player_selection(kart_id, power_id):
	rpc_id(1, "server_receive_selection", kart_id, power_id)

# 2. Server stores it and checks if everyone is ready
@rpc("any_peer")
func server_receive_selection(kart_id, power_id):
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Store the loadout
	if sender_id in players:
		player_loadouts[sender_id] = {
			"name": players[sender_id]["name"],
			"kart": kart_id,
			"power": power_id,
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
				
		# Tell everyone in the room to spawn the karts
		rpc_to_room(player_room_code, "client_start_race", room_loadouts)

# Helper function to check readiness
func _are_all_players_ready(player_room_code):
	for id in players:
		if players[id]["room"] == player_room_code:
			if not id in player_loadouts:
				return false # This person hasn't chosen yet
	return true

# Helper to send RPC only to people in a specific room
func rpc_to_room(player_room_code, function_name, data):
	for id in players:
		if players[id]["room"] == player_room_code:
			rpc_id(id, function_name, data)

# 3. Client receives the full list and starts
@rpc("authority")
func client_start_race(all_loadouts):
	# We emit a signal with the data so track.gd can use it
	emit_signal("game_started_with_loadouts", all_loadouts)
