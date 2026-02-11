extends Control

func _ready() -> void:
	%New.pressed.connect(new_game)
	
func new_game():
	var tracks: Array = GameData.tracks.keys()
	var track = tracks.pick_random()
	GameData.current_track = GameData.tracks[track]
	get_tree().change_scene_to_file("uid://dnd4ot45brbyk")
	
func settings():
	pass
	
func quit():
	get_tree().quit()
