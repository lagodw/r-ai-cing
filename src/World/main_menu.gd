extends Control

func _ready() -> void:
	%Single.pressed.connect(single_player)
	%Multi.pressed.connect(multi_player)
	%Settings.pressed.connect(settings)
	%Quit.pressed.connect(quit)
	
func single_player():
	#var tracks: Array = GameData.tracks.keys()
	#var track = tracks.pick_random()
	#GameData.current_track = GameData.tracks[track]
	#get_tree().change_scene_to_file("uid://dnd4ot45brbyk")
	MultiplayerManager._start_server()
func multi_player():
	MultiplayerManager.join_game()
	
func settings():
	$Settings.visible = true
	
func quit():
	get_tree().quit()
