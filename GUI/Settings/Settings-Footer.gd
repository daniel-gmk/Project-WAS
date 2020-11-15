extends ColorRect

##### Handles logic for footer menu in settings at the bottom

# Tracks the container that holds all the buttons in this menu
export var buttonBaseNodePath : NodePath
var buttonBaseNode

# Called when the node enters the scene tree for the first time.
func _ready():
	buttonBaseNode = get_node(buttonBaseNodePath)

# If escape button is pressed, call to go back to main menu
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_ESCAPE:
		exit_menu()

# Enables the footer menu's buttons
func enable():
	for child in buttonBaseNode.get_children():
		if child is Button:
			if child.name == "SaveButton":
				saveButtonCheck()
			else:
				child.disabled = false
		elif child.name == "EscMargin":
			child.get_node("HBoxContainer/BackButton").disabled = false

# Disables the footer menu's buttons
func disable():
	for child in buttonBaseNode.get_children():
		if child is Button:
			child.disabled = true
		elif child.name == "EscMargin":
			child.get_node("HBoxContainer/BackButton").disabled = true

# Checks if save button should be disabled or not based on whether any settings changes ocurred
func saveButtonCheck():
	var resetButton = find_node("ResetButton", true, false)
	if resetButton != null:
		var configFileNode = get_node("/root/GlobalConfigFile")
		resetButton.disabled = !(configFileNode.check_changed())

# Handles logic for leaving back to main menu if keybind menu is not up
func exit_menu():
	if !get_parent().keybindUse:
			get_tree().change_scene("res://MainMenu.tscn")

# If back button is pressed, call to go back to main menu
func _on_BackButton_pressed():
	exit_menu()

# If discard button is pressed, call parent to open discard menu
func _on_DiscardButton_pressed():
	get_parent().discardConfirm()

# If reset button is pressed, call parent to open reset menu
func _on_ResetButton_pressed():
	get_parent().resetConfirm()
