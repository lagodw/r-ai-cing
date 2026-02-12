extends CanvasLayer

@onready var slot_1_progress: TextureProgressBar = %Slot1Bar
@onready var slot_2_progress: TextureProgressBar = %Slot2Bar
var player_kart: Kart

func setup(kart: Kart) -> void:
	player_kart = kart
	player_kart.cooldown_started.connect(_on_cooldown_started)
	player_kart.lap_finished.connect(update_lap)
	%Icon1.texture = load("res://assets/powers/%s.png" % GameData.selected_powers[0].id)
	%Icon2.texture = load("res://assets/powers/%s.png" % GameData.selected_powers[1].id)
	update_lap(0)
	visible = true

func update_lap(laps_completed):
	%Laps.text = "%s / %s" % [laps_completed + 1, GameData.current_track.laps_required]

func _on_cooldown_started(slot_index: int, duration: float):
	var progress_bar: TextureProgressBar
	
	# Map slot index to UI element
	match slot_index:
		0: progress_bar = slot_1_progress
		1: progress_bar = slot_2_progress
		_: return # We only have 2 slots in UI
	
	# Animate the progress bar
	if progress_bar:
		progress_bar.max_value = duration * 100 # Multiplier for smoothness
		progress_bar.value = duration * 100
		
		var tween = create_tween()
		# Tween value from Max to 0 over 'duration' seconds
		tween.tween_property(progress_bar, "value", 0, duration)
