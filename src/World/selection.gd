extends CanvasLayer

@onready var kart_option = preload("uid://cppo8q4w7blh2")
@onready var projectile_option = preload("uid://ds4i1xicjsovx")

func _ready() -> void:
	$KartSelection/ConfirmKart.pressed.connect(confirm_kart)
	$PowerSelection/ConfirmPower.pressed.connect(confirm_power)
	
	var karts = GameData.karts.keys().duplicate(true)
	karts.shuffle()
	for i in 3:
		if karts.size() > 0:
			var kart = karts.pop_front()
			var option = kart_option.instantiate()
			option.kart = GameData.karts[kart]
			%Karts.add_child(option)

	var powers = GameData.powers.keys().duplicate(true)
	powers.shuffle()
	for i in 6:
		if powers.size() > 0:
			var power_id = powers.pop_front()
			var power: PowerDef = GameData.powers[power_id]
			if power.type == "projectile":
				var option = projectile_option.instantiate()
				option.power = power
				%Powers.add_child(option)

func confirm_kart():
	$KartSelection.visible = false
	$PowerSelection.visible = true
	
func confirm_power():
	queue_free()
