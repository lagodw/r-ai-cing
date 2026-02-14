extends Node

signal connection_failed
signal connection_succeeded
signal server_disconnected

var peer = WebSocketMultiplayerPeer.new()
const PORT = 8080

# START HERE:
# 1. For local testing, use "ws://127.0.0.1:8080"
# 2. For Production (Render/VPS), use "wss://your-app-name.onrender.com"
# Note: Android REQUIRES "wss://" (Secure) if you are not on a local network!
const LIVE_SERVER_URL = "wss://your-game-name.onrender.com"
const LOCAL_SERVER_URL = "ws://127.0.0.1:8080"

# Set this to true when you are ready to publish!
const IS_PROD_BUILD = false 

func _ready():
	# If this is the specialized "Headless Server" build, start listening
	if "--server" in OS.get_cmdline_args() or OS.has_feature("dedicated_server"):
		_start_server()

func _start_server():
	print("Starting Server on Port " + str(PORT))
	# Server listens for incoming WebSocket connections
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func join_game():
	var target_url = LIVE_SERVER_URL if IS_PROD_BUILD else LOCAL_SERVER_URL
	print("Joining server at: " + target_url)
	
	# Both Android and Web will run this line:
	var error = peer.create_client(target_url)
	if error != OK:
		print("Failed to init client: " + str(error))
		emit_signal("connection_failed")
		return
		
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connection_success)
	multiplayer.connection_failed.connect(_on_connection_failure)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# --- Standard Signals (Same as before) ---
func _on_connection_success():
	emit_signal("connection_succeeded")

func _on_connection_failure():
	emit_signal("connection_failed")

func _on_server_disconnected():
	emit_signal("server_disconnected")

func _on_peer_connected(id):
	_spawn_player(id)

func _on_peer_disconnected(id):
	if get_node_or_null(str(id)):
		get_node(str(id)).queue_free()

func _spawn_player(id):
	# Your spawn logic
	pass
