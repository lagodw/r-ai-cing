extends CanvasLayer

func _ready() -> void:
	$Panel/VBoxContainer/Resume.pressed.connect(resume)
	$Panel/VBoxContainer/Settings.pressed.connect(settings)
	$Panel/VBoxContainer/Main.pressed.connect(main_menu)

func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			visible = not visible
			get_tree().paused = not get_tree().paused
			
func resume():
	get_tree().paused = false
	visible = false
	
func settings():
	$Settings.visible = true
	
func main_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/World/main_menu.tscn")
