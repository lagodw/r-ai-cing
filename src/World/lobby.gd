extends Control

func _ready():
	# 1. Check if we are actually connected!
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		print("ERROR: User is NOT connected. Returning to Main Menu.")
		%StatusLabel.text = "Connection Lost. Go back."
		# Optional: Send them back to menu automatically
		# get_tree().change_scene_to_file("res://World/main_menu.tscn")
		return

	# 2. Connect buttons (Existing code)
	%HostButton.pressed.connect(_on_host_pressed)
	%JoinButton.pressed.connect(_on_join_pressed)
	
	MultiplayerManager.player_list_updated.connect(_update_ui)
	MultiplayerManager.game_started.connect(_start_game)

func _on_host_pressed():
	var player_name = %NameInput.text
	if player_name == "": return
	MultiplayerManager.request_create_room(player_name)
	%StatusLabel.text = "Creating Room..."
	$Background/HostPanel.visible = true

func _on_join_pressed():
	var player_name = %NameInput.text
	var code = %CodeInput.text
	if player_name == "" or code.length() != 4: return
	MultiplayerManager.request_join_room(player_name, code)
	%StatusLabel.text = "Joining Room " + code + "..."
	$Background/HostPanel.visible = true
	%Start.visible = false

func _update_ui():
	# DEBUG LOG
	print("Updating UI. My Code: ", MultiplayerManager.room_code)
	print("Current Players Data: ", MultiplayerManager.players)

	if MultiplayerManager.room_code != "":
		%CodeInput.text = MultiplayerManager.room_code
		%LobbyName.text = MultiplayerManager.room_code
		%StatusLabel.text = "Room: " + MultiplayerManager.room_code
		
		var player_list_text = "Players:\n"
		for id in MultiplayerManager.players:
			var p = MultiplayerManager.players[id]
			
			# DEBUG LOG
			print("Checking Player ", id, " in room ", p["room"])
			
			if p["room"] == MultiplayerManager.room_code:
				player_list_text += p["name"] + "\n"
		
		%PlayerListLabel.text = player_list_text

func _start_game():
	# Switch scene
	get_tree().change_scene_to_file("res://World/MainGame.tscn")
