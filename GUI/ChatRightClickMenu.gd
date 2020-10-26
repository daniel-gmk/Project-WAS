extends PopupMenu

var infocus = false

# Called when the node enters the scene tree for the first time.
func _ready():
	connect("id_pressed", self, "_on_id_pressed")
	connect("mouse_entered", self, "_on_mouse_entered")
	connect("mouse_exited", self, "_on_mouse_exited")

func _on_mouse_entered():
	infocus = true

func _on_mouse_exited():
	infocus = false

func _on_id_pressed(id):
	var local_gui
	for gui_node in get_tree().get_nodes_in_group("localGUI"):
		local_gui = gui_node
		break
	if local_gui != null:
		if id == 1:
			local_gui.sendMessage(get_parent().chatSelectedUser + " was successfully muted", local_gui.player_node.clientName, 0, true)
		elif id == 2:
			local_gui.sendMessage(get_parent().chatSelectedUser + " was successfully reported", local_gui.player_node.clientName, 0, true)
		get_parent().chatSelectedUser = ""

func _input(event):
	if event is InputEventMouseButton:
		if (event.button_index == BUTTON_LEFT or event.button_index == BUTTON_RIGHT) and event.pressed and !infocus:
			for rightClickMenu in get_tree().get_nodes_in_group("RightClickMenu"):
				rightClickMenu.queue_free()
			if event.button_index == BUTTON_LEFT:
				get_parent().chatSelectedUser = ""
			elif event.button_index == BUTTON_RIGHT:
				if get_parent().chatSelectedUser != get_parent().chatHoveredUser:
					get_parent().chatSelectedUser = get_parent().chatHoveredUser
