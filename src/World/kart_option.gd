extends MarginContainer

signal selected(kart_def, node_ref)

@export var kart: KartDef

func _ready() -> void:
	$VBoxContainer/TextureRect.texture = load("res://assets/karts/%s.png"%kart.id)
	%SpeedBar.value = kart.max_speed
	%AccelerationBar.value = kart.acceleration
	%HandlingBar.value = kart.traction
	%WeightBar.value = kart.width_percent
	%Name.text = kart.id.replace("_", " ")
	%HealthBar.value = kart.max_health

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(kart, self)

func set_highlight(to_show: bool) -> void:
	$Highlight.visible = to_show
