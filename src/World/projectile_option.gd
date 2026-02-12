extends MarginContainer

signal selected(power_def, node_ref)

@export var power: PowerDef

func _ready() -> void:
	%Icon.texture = load("res://assets/powers/%s.png" % power.id)
	%Name.text = power.id
	%Type.text = str(power.projectile_behavior)
	%Damage.text = str(power.damage)
	%Speed.text = str(power.speed)
	%Duration.text = str(power.duration)
	%Cooldown.text = str(power.cooldown)
	
	if power.projectile_behavior == "orbit":
		%DurationBox.visible = true
		%SpeedBox.visible = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(power, self)

func set_highlight(to_show: bool) -> void:
	$Highlight.visible = to_show
