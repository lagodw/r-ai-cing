extends Node

# Code: src/Autoloads/AudioManager.gd

# We create a pool of players so multiple sound effects can play at once
const SFX_POOL_SIZE = 8

var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []

func _ready() -> void:
	# 1. Setup Music Player
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music" # Route to the Music bus we made
	add_child(_music_player)
	
	# 2. Setup SFX Pool
	for i in range(SFX_POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX" # Route to the SFX bus we made
		add_child(p)
		_sfx_pool.append(p)

# --- Playback Functions ---

func play_music(music_name: String, _crossfade_duration: float = 0.0):
	var stream: AudioStream = load("res://assets/audio/%s.mp3"%music_name)
	if _music_player.stream == stream and _music_player.playing:
		return
		
	_music_player.stream = stream
	_music_player.play()

func play_sfx(sfx_name: String, pitch_scale: float = 1.0):
	var stream: AudioStream = load("res://assets/audio/%s.mp3"%sfx_name)
	# Find the first available player in the pool
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch_scale
			p.play()
			return
	
	# If all busy, interrupt the oldest one (index 0) or just ignore
	# Ideally, we might prioritize simpler sounds, but this is sufficient.
	print("SFX Pool full, skipping sound.")

# --- Volume Control Functions ---

func set_bus_volume(bus_name: String, linear_value: float):
	# linear_value should be between 0.0 (mute) and 1.0 (max)
	var index = AudioServer.get_bus_index(bus_name)
	
	if index == -1:
		printerr("Bus not found: ", bus_name)
		return
	
	if linear_value <= 0.0:
		AudioServer.set_bus_mute(index, true)
	else:
		AudioServer.set_bus_mute(index, false)
		# Convert 0-1 range to Decibels
		AudioServer.set_bus_volume_db(index, linear_to_db(linear_value))
