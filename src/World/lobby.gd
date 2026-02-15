extends Control

func _ready():
	GameData.num_bots = 0
	# 1. Initialize UI State
	%HostButton.disabled = true
	%JoinButton.disabled = true
	%StatusLabel.text = "Connecting to Server..."
	%Start.pressed.connect(_on_start_pressed)
	
	%Minus.pressed.connect(change_num_bots.bind(-1))
	%Plus.pressed.connect(change_num_bots.bind(1))
	
	# 2. Connect Signals
	MultiplayerManager.connection_succeeded.connect(_on_connected)
	MultiplayerManager.player_list_updated.connect(_update_ui)
	MultiplayerManager.game_started.connect(_start_game)
	
	# 3. Connect Buttons
	%HostButton.pressed.connect(_on_host_pressed)
	%JoinButton.pressed.connect(_on_join_pressed)
	
	# 4. Join Server
	MultiplayerManager.join_server()

func _on_connected():
	$Background/ConnectingPanel.visible = false
	%StatusLabel.text = "Connected! Create or Join a Room."
	%HostButton.disabled = false
	%JoinButton.disabled = false
	
	# Debug print to confirm ID
	print("Connected successfully with ID: ", multiplayer.get_unique_id())
	
func _on_host_pressed():
	$Background/NamePanel.visible = true
	%ConfirmName.pressed.connect(confirm_host)

func confirm_host():
	var player_name = %NameInput.text
	if player_name == "": return
	MultiplayerManager.request_create_room(player_name)
	%StatusLabel.text = "Creating Room..."
	$Background/HostPanel.visible = true
	$Background/NamePanel.visible = false

func _on_join_pressed():
	$Background/NamePanel.visible = true
	%ConfirmName.pressed.connect(confirm_join)
	
func confirm_join():
	var code = %CodeInput.text
	var player_name = %NameInput.text
	if player_name == "" or code.length() != 4: return
	MultiplayerManager.request_join_room(player_name, code)
	%StatusLabel.text = "Joining Room " + code + "..."
	$Background/HostPanel.visible = true
	$Background/NamePanel.visible = false
	%Start.visible = false
	%BotBox.visible = false

func _update_ui():
	if MultiplayerManager.room_code != "":
		%CodeInput.text = MultiplayerManager.room_code
		%LobbyName.text = MultiplayerManager.room_code
		%StatusLabel.text = "Room: " + MultiplayerManager.room_code
		
		var player_list_text = ""
		for id in MultiplayerManager.players:
			var p = MultiplayerManager.players[id]
			
			if p["room"] == MultiplayerManager.room_code:
				player_list_text += p["name"] + "\n"
		
		%PlayerListLabel.text = player_list_text

func _start_game():
	# Switch scene
	get_tree().change_scene_to_file("res://src/World/Track.tscn")

func confirm_name():
	$Background/NamePanel.visible = false
	$Background/HostPanel.visible = true

func change_num_bots(change: int):
	GameData.num_bots = clamp(GameData.num_bots + change, 0, 7)
	%NumBots.text = str(GameData.num_bots)

func _on_start_pressed():
	MultiplayerManager.request_start_game()
