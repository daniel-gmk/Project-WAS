extends PopupMenu

##### This node is what gets dynamically generated and shown when you right click someone in chat, allowing actions like reporting or muting

# Track whether the mouse is hovered over the menu or not
# Allows different actions like left click behavior whether it is in the menu or not
# For example, left click inside the menu should select the option, outside should exit out of the menu
var infocus = false

# Called when the right click menu is loaded
func _ready():
	# Connect signals for native control commands
	connect("id_pressed", self, "_on_id_pressed")
	connect("mouse_entered", self, "_on_mouse_entered")
	connect("mouse_exited", self, "_on_mouse_exited")

# When mouse enters the menu
func _on_mouse_entered():
	infocus = true

# When mouse leaves the menu
func _on_mouse_exited():
	infocus = false

# When a menu item is pressed
func _on_id_pressed(id):
	# Track the GUI root mode captured in a node group because this component is dynamically generated
	var local_gui
	if get_tree().get_nodes_in_group("localGUI").size() == 1:
		local_gui = get_tree().get_nodes_in_group("localGUI")[0]
	else:
		print("Error: there should be only one local GUI component")

	# If valid local ui
	if local_gui != null:
		# ID 1 is MUTE
		if id == 1:
			local_gui.sendMessage(get_parent().chatSelectedUser + " was successfully muted", local_gui.player_node.clientName, 0, true)
		# ID 2 is REPORT
		elif id == 2:
			local_gui.sendMessage(get_parent().chatSelectedUser + " was successfully reported", local_gui.player_node.clientName, 0, true)

# When input is pressed
func _input(event):
	if event is InputEventMouseButton:
		# If there is a left or right click BUT only outside the right click menu
		if (event.button_index == BUTTON_LEFT or event.button_index == BUTTON_RIGHT) and event.pressed and !infocus:
			# Remove all right click menus
			for rightClickMenu in get_tree().get_nodes_in_group("RightClickMenu"):
				rightClickMenu.queue_free()
