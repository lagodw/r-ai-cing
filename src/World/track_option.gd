extends TextureRect

signal selected(node: Control)

var track_id: String

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(self)

func set_highlight(to_show: bool) -> void:
	$Highlight.visible = to_show
