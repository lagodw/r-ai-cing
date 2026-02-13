extends MarginContainer

signal selected(power_def, node_ref)

@export var power: PowerDef

func _ready() -> void:
	%Icon.texture = load("res://assets/powers/%s.png" % power.id)
	%PowerType.text = power.type
	%Name.text = power.id
	%Type.text = str(power.projectile_behavior)
	%Damage.text = str(power.damage)
	%Speed.text = str(power.speed)
	%Duration.text = str(power.duration)
	%Cooldown.text = str(power.cooldown)
	%Count.text = str(power.projectile_count)
	%Stat.text = power.stat_target
	%Amount.text = str(power.amount)
	
	match power.type:
		"Projectile":
			%SpeedBox.visible = false
			%DurationBox.visible = false
			%StatBox.visible = false
			%AmountBox.visible = false
			if power.projectile_behavior == "Orbit":
				%DurationBox.visible = true
				%SpeedBox.visible = false
		"Hazard":
			%SpeedBox.visible = false
			%DurationBox.visible = false
			%StatBox.visible = false
			%AmountBox.visible = false
		"Buff":
			%CountBox.visible = false
			%DurationBox.visible = false
			%TypeBox.visible = false
			%DamageBox.visible = false
			%SpeedBox.visible = false
		

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(power, self)

func set_highlight(to_show: bool) -> void:
	$Highlight.visible = to_show
