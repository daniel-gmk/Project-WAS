extends RichTextLabel

##### This node allows custom functionality for the primary GUI chat menu

# Tracks the user in chat that the player right clicked
var chatSelectedUser = ""
# Tracks the user hovered over in chat so the player can right click the correct chat sender
var chatHoveredUser = ""

# When the node loads
func _ready():
	# Connect signals for native control commands
	connect("meta_hover_started", self, "_on_meta_hover_started")
	connect("meta_hover_ended", self, "_on_meta_hover_ended")

# When the mouse hovers over the text bbcode meta tags that track who sent the message
func _on_meta_hover_started(meta):
	# Check just in case the text hovered over is valid
	if meta != null:
		# Always update the hovered user in case the right click menu is open
		chatHoveredUser = meta

# When the mouse no longer hovers over the text bbcode meta tags that track who sent the message
func _on_meta_hover_ended(meta):
	# Check just in case the text hovered over is valid
	if meta != null:
		# Always reset the hovered user in case the right click menu is open
		chatHoveredUser = ""

# Track inputs on the gui component only
func _gui_input(event):
	# When right click is pressed over the chat menu
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_RIGHT and event.pressed:

			# Track the GUI root mode captured in a node group because this component is dynamically generated
			var local_gui
			if get_tree().get_nodes_in_group("localGUI").size() == 1:
				local_gui = get_tree().get_nodes_in_group("localGUI")[0]
			else:
				print("Error: there should be only one local GUI component")

			# A new right click removes all existing right click menus
			for rightClickMenu in get_tree().get_nodes_in_group("RightClickMenu"):
				rightClickMenu.queue_free()

			# Set selected user
			chatSelectedUser = chatHoveredUser

			# If valid selected user and gui
			if local_gui != null and chatSelectedUser != local_gui.player_node.clientName and chatSelectedUser != "":
				
				# Dynamically create right click menu
				var thing = PopupMenu.new()
				thing.name = "ChatRightClick"
				var rightClickScript = load("res://GUI/ChatRightClickMenu.gd")
				thing.set_script(rightClickScript)
				thing.add_item("Mute", 1)
				thing.add_item("Report", 2)
				thing.rect_position = get_viewport().get_mouse_position()
				thing.add_to_group("RightClickMenu")
				add_child(thing)
				thing.visible = true
