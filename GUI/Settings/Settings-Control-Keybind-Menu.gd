extends ColorRect

##### Controls sub-menu handling keybind logic

# Can't find Godot built in way to convert mouse button to human readable text, array holds those values for now
var mouseToString = ["Error", "Left Mouse Button", "Right Mouse Button", "Scroll Wheel (Press)", "Scroll Wheel (Up)", "Scroll Wheel (Down)", "Mouse 4", "Mouse 5"]
# Tracks the keybind human readable text to read to user
var keyText
# Tracks the Godot keybind object to change to
var keyBind

# Tracks the sub element that holds the text to put human readable converted keybind text in
export var inputLabelNodePath : NodePath
var inputLabelNode
# Tracks the sub element that holds the menu that lets you select mouse button
export var mouseButtonNodePath : NodePath
var mouseButtonNode
# Tracks if the node is initialized or not
var initialized = false

# Called when the node is manually initialized
func initialize(key, keybindName):
	# Set nodes and variables
	inputLabelNode = get_node(inputLabelNodePath)
	setMouseButtonNode()
	inputLabelNode.text = keybindName
	keyBind = key
	keyText = keybindName
	# Disable buttons in footer since a menu is up
	var settingsNode = get_tree().get_nodes_in_group("Settings")
	if settingsNode.size() == 1:
		settingsNode[0].get_node("Footer").disable()
	# Set as initialized
	initialized = true

# Creates the sub menus 
func setMouseButtonNode():
	mouseButtonNode = get_node(mouseButtonNodePath)
	mouseButtonNode.add_item("Not Selected")
	for i in range(1, mouseToString.size()):
		mouseButtonNode.add_item(mouseToString[i])

# Handles when any key is pressed to set keybind
func _unhandled_input(event):
	if initialized and event is InputEventKey and event.is_pressed():
		# Set keybind
		keyBind = event
		# Set text for keybind
		var text = OS.get_scancode_string(event.scancode)
		keyText = text
		inputLabelNode.text = text
		# Reset mouse button menu to first "non selected" menu option
		mouseButtonNode.select(0)

# Sets mouse key and text when a mouse button menu item is selected
func _on_MouseButton_item_selected(index):
	if initialized and index != 0:
		# Set mouse text
		var text = mouseToString[index]
		keyText = text
		inputLabelNode.text = text
		# Set mouse key
		var newMouseKey = InputEventMouseButton.new()
		newMouseKey.button_index = index
		keyBind = newMouseKey

# Closing and exiting the menu
func exit_node():
	# Enable footer buttons
	var settingsNode = get_tree().get_nodes_in_group("Settings")
	if settingsNode.size() == 1:
		settingsNode[0].keybindUse = false
		settingsNode[0].get_node("Footer").enable()
	# Terminate
	queue_free()

# Cancel button pressed
func _on_CancelButton_pressed():
	exit_node()

# Confirm button pressed
func _on_ConfirmButton_pressed():
	if initialized:
		print("Confirmed")
		exit_node()
		# Will add functionality later
