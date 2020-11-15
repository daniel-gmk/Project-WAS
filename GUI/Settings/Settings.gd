extends Control

### Handles logic for settings base node, loading elements

# Checks if a keybind is being changed and menu is open
var keybindUse = false

# Tracks node path for center container that changes as menus are selected
export var mainCenterContainerPath : NodePath
# Tracks node for center container
var mainCenterContainer

# Absolute path to settings folder containing settings sub-menu scenes
var settingsNodePath = "res://GUI/Settings/"

# Tracks nodes and instantiation nodes for general setting options GUI
var generalSettingsNodeName = "Settings-General"
var generalSettingsNodeScene

# Tracks nodes and instantiation nodes for keybind/control setting options GUI
var controlsSettingsNodeName = "Settings-Control"
var controlsSettingsNodeScene

# Tracks nodes and instantiation nodes for video setting options GUI
var videoSettingsNodeName = "Settings-Video"
var videoSettingsNodeScene

# Tracks nodes and instantiation nodes for audio setting options GUI
var audioSettingsNodeName = "Settings-Audio"
var audioSettingsNodeScene

# Called when the node enters the scene tree for the first time.
func _ready():
	# Set as single node in a group for nested children to easily access
	add_to_group("Settings")
	# Get center container so we can set it as a given sub-menu
	mainCenterContainer = get_node(mainCenterContainerPath)

	# Load scenes from path
	generalSettingsNodeScene = load(settingsNodePath + generalSettingsNodeName + ".tscn")
	controlsSettingsNodeScene = load(settingsNodePath + controlsSettingsNodeName + ".tscn")
	videoSettingsNodeScene = load(settingsNodePath + videoSettingsNodeName + ".tscn")
	audioSettingsNodeScene = load(settingsNodePath + audioSettingsNodeName + ".tscn")
	
	# Set initial center container as general
	var generalSettingsNodeInstance = generalSettingsNodeScene.instance()
	mainCenterContainer.add_child(generalSettingsNodeInstance)

# Switch to General sub-menu
func _on_General_pressed():
	setMainCenterContainer(generalSettingsNodeScene)

# Switch to Controls sub-menu
func _on_Controls_pressed():
	setMainCenterContainer(controlsSettingsNodeScene)

# Switch to Video sub-menu
func _on_Video_pressed():
	setMainCenterContainer(videoSettingsNodeScene)

# Switch to Audio sub-menu
func _on_Audio_pressed():
	setMainCenterContainer(audioSettingsNodeScene)

# Changing the central container to corresponding sub-menu
func setMainCenterContainer(nodeScene):
	# Prompt for saving changes
	# Remove existing sub-menu
	var children = mainCenterContainer.get_children()
	for n in children:
		if n.name != "_h_scroll" and n.name != "_v_scroll":
			mainCenterContainer.remove_child(n)
			n.queue_free()
	# Instantiate and add new sub-menu
	var nodeInstance = nodeScene.instance()
	mainCenterContainer.call_deferred("add_child", nodeInstance)

# Open new menu confirming discarding settings
func discardConfirm():
	var discardConfirmNodeScene = load("res://GUI/Settings/Settings-Discard-Confirm.tscn")
	var discardConfirmNodeInstance = discardConfirmNodeScene.instance()
	add_child(discardConfirmNodeInstance)

# Open new menu confirming reset settings
func resetConfirm():
	var resetConfirmNodeScene = load("res://GUI/Settings/Settings-Reset-Confirm.tscn")
	var resetConfirmNodeInstance = resetConfirmNodeScene.instance()
	add_child(resetConfirmNodeInstance)

# After confirmation of discarding settings, discard settings
func discardSettings():
	var configFileNode = get_node("/root/GlobalConfigFile")
	configFileNode.discard_settings()

# After confirmation of resetting settings, reset settings
func resetSettings():
	var configFileNode = get_node("/root/GlobalConfigFile")
	configFileNode.reset_settings()
