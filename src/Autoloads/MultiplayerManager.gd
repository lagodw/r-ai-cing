extends Node

signal connection_failed
signal connection_succeeded
signal server_disconnected

var peer = WebSocketMultiplayerPeer.new()
var port = 8080

# START HERE:
# 1. For local testing, use "ws://127.0.0.1:8080"
# 2. For Production (Render/VPS), use "wss://your-app-name.onrender.com"
# Note: Android REQUIRES "wss://" (Secure) if you are not on a local network!
const LIVE_SERVER_URL = "wss://r-ai-cing.onrender.com"
const LOCAL_SERVER_URL = "ws://127.0.0.1:8080"

# Set to true when exporting for Web/Android
const IS_PROD_BUILD = true 

# Connection State
var _is_connecting = false
var _connection_timer = 0.0
const MAX_WAIT_TIME = 60.0 # Wait up to 60 seconds for server to wake up

func _ready():
	# Check if we are on the server
	if "--server" in OS.get_cmdline_args() or OS.has_feature("dedicated_server"):
		_start_server()

func _process(delta):
	peer.poll() # Keep the connection alive
	
	if _is_connecting:
		_connection_timer += delta
		if _connection_timer >= MAX_WAIT_TIME:
			_is_connecting = false
			print("Connection timed out completely.")
			emit_signal("connection_failed")
			peer.close()

func _start_server():
	# 1. Get the PORT from Render's Environment Variable
	var env_port = OS.get_environment("PORT")
	if env_port != "":
		port = int(env_port)
	
	print("Starting Server on Port " + str(port))
	
	# 2. Bind specifically to "0.0.0.0" (IPv4)
	# This is CRITICAL for Render to detect the app!
	var error = peer.create_server(port, "0.0.0.0")
	if error != OK:
		print("FAILED to start server: " + str(error))
		return
		
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Server listening on " + str(port))
	
func join_game():
	_is_connecting = true
	_connection_timer = 0.0
	
	var target_url = LIVE_SERVER_URL if IS_PROD_BUILD else LOCAL_SERVER_URL
	print("Attempting to connect to: " + target_url)
	
	var error = peer.create_client(target_url)
	if error != OK:
		print("Client creation failed: " + str(error))
		emit_signal("connection_failed")
		_is_connecting = false
		return
		
	multiplayer.multiplayer_peer = peer
	
	# Connect signals to detect when we actually succeed/fail
	multiplayer.connected_to_server.connect(_on_connection_success)
	multiplayer.connection_failed.connect(_on_connection_failure)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_connection_success():
	print("Connected successfully!")
	_is_connecting = false # Stop the timer
	emit_signal("connection_succeeded")

func _on_connection_failure():
	# This usually happens if the server is unreachable or refuses connection
	print("Connection failed.")
	_is_connecting = false
	emit_signal("connection_failed")

func _on_server_disconnected():
	print("Disconnected from server.")
	emit_signal("server_disconnected")

# --- Player Handling ---
func _on_peer_connected(id):
	print("Player connected: " + str(id))
	_spawn_player(id)

func _on_peer_disconnected(id):
	if get_node_or_null(str(id)):
		get_node(str(id)).queue_free()

func _spawn_player(_id):
	# Your spawn logic
	pass
