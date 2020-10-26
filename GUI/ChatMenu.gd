extends RichTextLabel


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
var chatSelectedUser = ""
var chatHoveredUser = ""

func _ready():
	connect("meta_hover_started", self, "_on_meta_hover_started")
	connect("meta_hover_ended", self, "_on_meta_hover_ended")

func _on_meta_hover_started(meta):
	if meta != null:
		if get_tree().get_nodes_in_group("RightClickMenu").size() == 0:
			chatSelectedUser = meta
			chatHoveredUser = meta
		else:
			chatHoveredUser = meta
			
func _on_meta_hover_ended(meta):
	if meta != null:
		if get_tree().get_nodes_in_group("RightClickMenu").size() == 0:
			chatSelectedUser = ""
			chatHoveredUser = ""
		else:
			chatHoveredUser = ""

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_RIGHT and event.pressed:
			var local_gui
			for gui_node in get_tree().get_nodes_in_group("localGUI"):
				local_gui = gui_node
				break
			for rightClickMenu in get_tree().get_nodes_in_group("RightClickMenu"):
				rightClickMenu.queue_free()
			if chatSelectedUser != chatHoveredUser:
				chatSelectedUser = chatHoveredUser
			if local_gui != null and chatSelectedUser != local_gui.player_node.clientName and chatSelectedUser != "":
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
