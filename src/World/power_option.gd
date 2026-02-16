extends MarginContainer

signal selected(power_def, node_ref)

@export var power: PowerDef

func _ready() -> void:
	%Icon.texture = load("res://assets/powers/%s.png" % power.id)
	%PowerType.text = power.type
	%Description.text = power.description
	%Name.text = power.id
	%Type.text = str(power.projectile_behavior)
	%Damage.text = str(power.damage)
	%Speed.text = str(power.speed)
	%Duration.text = str(power.effect_duration)
	%Cooldown.text = str(power.cooldown)
	%Count.text = str(power.projectile_count)
	%Stat.text = power.stat_target
	%Amount.text = str(power.amount)
	
	%Description.text = power.description
	
	#%CountBox.visible = power.type != "Buff"
	#%DamageBox.visible = power.damage > 0
	#%StatBox.visible = power.effect_duration > 0
	#%AmountBox.visible = power.amount > 0
	#%DurationBox.visible = power.effect_duration > 0
	#
	#
	#match power.type:
		#"Projectile":
			#%SpeedBox.visible = false
			#%StatBox.visible = false
			#%AmountBox.visible = false
		#"Hazard":
			#%DurationBox.visible = false
			#%StatBox.visible = false
			#%AmountBox.visible = false
		#"Buff":
			#%CountBox.visible = false
			#%TypeBox.visible = false
			#%DamageBox.visible = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(power, self)

func set_highlight(to_show: bool) -> void:
	$Highlight.visible = to_show
