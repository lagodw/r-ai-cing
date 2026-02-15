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
	print("Received player list from server: ", new_players) # DEBUG LOG
	
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
		print("My room code is: ", room_code) # DEBUG LOG
	else:
		print("ERROR: I am not in the player list!")
	
	emit_signal("player_list_updated")

# --- Gameplay Start ---
func start_game():
	# Only the host (or anyone in the room) can call this
	emit_signal("game_started")

# --- Standard boilerplate ---
func _on_connection_success(): emit_signal("connection_succeeded")
func _on_peer_connected(_id): pass # We handle this in register_player now
func _on_peer_disconnected(id):
	if multiplayer.is_server():
		players.erase(id)
		rpc("update_player_list", players)
