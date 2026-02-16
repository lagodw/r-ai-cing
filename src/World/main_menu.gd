extends Control

func _ready() -> void:
	%Single.pressed.connect(single_player)
	%Multi.pressed.connect(multi_player)
	%Settings.pressed.connect(settings)
	%Quit.pressed.connect(quit)
	
	if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		print('connected')
	
func single_player():
	GameData.is_singleplayer = true
	var tracks: Array = GameData.tracks.keys()
	var track = tracks.pick_random()
	GameData.current_track = GameData.tracks[track]
	get_tree().change_scene_to_file("uid://dnd4ot45brbyk")
	
func multi_player():
	GameData.is_singleplayer = false
	get_tree().change_scene_to_file("res://src/World/lobby.tscn")
	
func settings():
	$Settings.visible = true
	
func quit():
	get_tree().quit()
