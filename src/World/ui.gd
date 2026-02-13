extends CanvasLayer

@onready var slot_1_progress: TextureProgressBar = %Slot1Bar
@onready var slot_2_progress: TextureProgressBar = %Slot2Bar
var player_kart: Kart

func _ready() -> void:
	var is_mobile = OS.has_feature("mobile") or \
						OS.has_feature("web_android") or \
						OS.has_feature("web_ios")
	#if not is_mobile and not OS.has_feature("editor"):
	if not is_mobile:
		$VirtualJoystick.queue_free()
		$Menu.visible = false
	else:
		# have competing TouchScreenButton
		$HBoxContainer/Power1.disabled = true
		$HBoxContainer/Power2.disabled = true
		$HBoxContainer/Power1/Label1.visible = false
		$HBoxContainer/Power2/Label2.visible = false

func setup(kart: Kart) -> void:
	player_kart = kart
	player_kart.cooldown_started.connect(_on_cooldown_started)
	player_kart.lap_finished.connect(update_lap)
	%Power1.icon = load("res://assets/powers/%s.png" % GameData.selected_powers[0].id)
	%Power2.icon = load("res://assets/powers/%s.png" % GameData.selected_powers[1].id)
	%Power1.pressed.connect(player_kart.activate_power_effect.bind(0))
	%Power2.pressed.connect(player_kart.activate_power_effect.bind(1))
	update_lap(0)
	visible = true
	$Menu.pressed.connect(show_menu)

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

func show_menu():
	get_tree().current_scene.get_node("Escape").visible = true
	get_tree().paused = true
