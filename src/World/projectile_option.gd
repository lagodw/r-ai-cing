extends MarginContainer

@export var power: PowerDef

func _ready() -> void:
	%Name.text = power.id
	%Type.text = str(power.projectile_behavior)
	%Damage.text = str(power.damage)
	%Speed.text = str(power.speed)
	%Duration.text = str(power.duration)
	%Cooldown.text = str(power.cooldown)
	if power.projectile_behavior == "orbit":
		%DurationBox.visible = true
		%SpeedBox.visible = false
