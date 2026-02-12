extends MarginContainer

@export var kart: KartDef

func _ready() -> void:
	$VBoxContainer/TextureRect.texture = load("res://assets/karts/%s.png"%kart.id)
	%SpeedBar.value = kart.max_speed
	%AccelerationBar.value = kart.acceleration
	%HandlingBar.value = kart.turn_speed
	%WeightBar.value = kart.length * kart.width
	%Name.text = kart.kart_name
