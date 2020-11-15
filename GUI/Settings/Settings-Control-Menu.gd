extends VBoxContainer

### Handles logic for settings control nodes specifically, base for each settings sub-menu

# Can't find Godot built in way to convert mouse button to human readable text, array holds those values for now
var mouseToString = ["Error", "Left Mouse Button", "Right Mouse Button", "Scroll Wheel (Press)", "Scroll Wheel (Up)", "Scroll Wheel (Down)", "Mouse 4", "Mouse 5"]
# Tracks the parent control node
var controlNode
# Tracks the keybind menu to load it dynamically when needed
var keybindMenuNodeScene
var keybindMenuNodeInstance

# Called when the node enters the scene tree for the first time.
func _ready():
	controlNode = get_node("/root/Settings/Control")
	
	# If menu is a control menu for keybinds, set the name for all keybind buttons as the current keybind
	var children = get_children()
	for c in children:
		if c is ColorRect and c.name != "ColorRect":
			if c.has_node("HBoxContainer"):
				var elementChildren = c.get_node("HBoxContainer").get_children()
				for ec in elementChildren:
					if ec is Button and ec.name != "OptionButton":
						var inputmap = InputMap.get_action_list(ec.name)[0]
						var text
						if inputmap is InputEventMouseButton:
							text = mouseToString[inputmap.button_index]
							ec.text = text
							ec.connect("pressed", self, "keybindMenu", [inputmap, text])
						elif inputmap is InputEventKey:
							text = OS.get_scancode_string(InputMap.get_action_list(ec.name)[0].scancode)
							ec.text = text
							ec.connect("pressed", self, "keybindMenu", [inputmap, text])

# Open the keybind menu to change keybind
func keybindMenu(key, keybindName):
	keybindMenuNodeScene = load("res://GUI/Settings/Settings-Control-Keybind-Menu.tscn")
	keybindMenuNodeInstance = keybindMenuNodeScene.instance()
	controlNode.add_child(keybindMenuNodeInstance)
	keybindMenuNodeInstance.initialize(key, keybindName)
	var settingsNode = get_tree().get_nodes_in_group("Settings")
	if settingsNode.size() == 1:
		settingsNode[0].keybindUse = true

# When master volume slider is changed, update text
func _on_MasterVolumeSlider_value_changed(value):
	find_node("MasterVolumeLabel", true, false).text = str(value)

# When music volume slider is changed, update text
func _on_MusicVolumeSlider_value_changed(value):
	find_node("MusicVolumeLabel", true, false).text = str(value)

# When effects volume slider is changed, update text
func _on_EffectsVolumeSlider_value_changed(value):
	find_node("EffectsVolumeLabel", true, false).text = str(value)

# When minimized volume slider is changed, update text
func _on_MinimizedVolumeSlider_value_changed(value):
	find_node("MinimizedVolumeLabel", true, false).text = str(value)
