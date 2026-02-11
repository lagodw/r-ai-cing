extends Node

const PORT = 8910
var peer = ENetMultiplayerPeer.new()
var kart_scene = preload("res://src/Entities/Kart.tscn")

func host_game():
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	
	# Event: When someone connects, spawn a kart for them
	multiplayer.peer_connected.connect(_spawn_player)
	
	# Spawn my own kart
	_spawn_player(1)

func join_game(address = "127.0.0.1"):
	peer.create_client(address, PORT)
	multiplayer.multiplayer_peer = peer

func _spawn_player(peer_id):
	var k = kart_scene.instantiate()
	k.name = str(peer_id) # Important: Name must match ID for authority
	k.position = Vector2(200, 300) # (In reality, use a spawn point array)
	
	# Add to the scene. The MultiplayerSpawner will detect this 
	# and automatically replicate it to all clients!
	get_tree().current_scene.add_child(k)
