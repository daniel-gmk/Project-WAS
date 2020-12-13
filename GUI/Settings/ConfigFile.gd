extends Node

##### This Singleton handles saving data/settings to local file

# Track success/failure 
enum {LOAD_SUCCESS, LOAD_ERROR_COULDNT_OPEN}

# Save path
const SAVE_PATH = "user://config.cfg"

# Config file object
var _config_file = ConfigFile.new()
# Current non-persistent settings
var _settings
# Initial settings to check if settings changed
var _settings_initial
# Default settings for resetting if pressed
var _settings_default = {
	# Replace a lot of these with Globals
	"UI": {
		"Language" : "English",
		"ColorblindMode" : false,
		"MinimapLocation" : "Bottom Right"
	},
	"Controls": {
		"EscMenu" : 16777217,
		"SkillsetMenu" : 78,
		"left" : 65,
		"right" : 68,
		"jump" : 32,
		"shoot" : 1,
		"MinionSwitch" : 90,
		"Scoreboard" : 16777218,
		"Chat" : 16777221,
		"SkillLayout" : "Expert",
		"CastMode" : 16777237,
		"Skill1" : 81,
		"Skill2" : 87,
		"Skill3" : 69,
		"Skill4" : 82,
		"Skill5" : 84,
		"Skill6" : 89,
		"Ultimate1" : 49,
		"Ultimate2" : 50,
		"Ultimate3" : 51,
		"DragCamera" : 2,
		"ResetCamera" : 3,
		"CameraZoomIn" : 4,
		"CameraZoomOut" : 5
	},
	"Video" : { # Auto detection down the road
		"DisplayMode" : "Fullscreen",
		"Resolution" : [1920, 1080],
		"FrameRate" : 144,
		"V-Sync" : false,
		"Preset" : "Very High",
		"Texture" : "High",
		"Effects" : "High",
		"Anti-Aliasing" : "FXAA"
	},
	"Audio" : {
		"MasterVolume" : 100,
		"MusicVolume" : 100,
		"EffectsVolume" : 100,
		"VolumeWhileMinimized" : 100
	},
	"Character" : {
		"Selected" : 0,
		"OverallDefensesPreset" : [0,1,2,3,4,5],
		"0" : {
			"Attacks" : ["Projectile","Projectile2","Projectile3","Projectile4","Projectile5","Projectile6"],
			"Ultimates" : ["Projectile","Projectile2","Projectile3"],
			"DefensesPreset" : [0,1,2,3,4,5]
		}
	}
}

# When singleton/game loads
func _ready():
	# Set settings as default in case this is the first time loading
	_settings = _settings_default
	# Try to load config file to check if it exists
	var error = _config_file.load(SAVE_PATH)
	# If there is an error loading the file
	if error != OK:
		# If config file does not exist, load default settings for the first time
		if error == 7:
			save_settings(_settings)
			load_settings(true)
		# If there is some other error then that is bad :(
		else:
			print("Error loading the settings. Error code: %s" % error)
	else:
		# Load the existing settings
		load_settings(true)
	
	# Load keybinds from settings
	load_keybinds()

# The configFile has sections, and key-value pairs. The first loop retrieves the section name in the _settings dictionary
# The second loop goes one level deeper inside the dictionary and gives you the key (key) value (_settings[section][key]) pairs,
# e.g. key will first be "mute" and _settings[section][key] false
func save_settings(settings_dict):
	for section in settings_dict.keys():
		for key in settings_dict[section].keys():
			# The ConfigFile object (_config_file is a ConfigFile) has all the methods you need to load, save, set and read values
			_config_file.set_value(section, key, settings_dict[section][key])

	_config_file.save(SAVE_PATH)
	_settings_initial = _settings

func load_settings(initial):
	# If the file doesn't open correctly (doesn't exist or used by another process),
	# We can't load any data so we return outside the function
	# NB: You could check if the file exist with the File object
	var error = _config_file.load(SAVE_PATH)
	if error != OK:
		print("Error loading the settings. Error code: %s" % error)
		return LOAD_ERROR_COULDNT_OPEN

	for section in _settings.keys():
		for key in _settings[section].keys():
			# We store the settings in the dictionary. In this demo, it's up to the other nodes to retrieve the settings,
			# with get_setting and set_setting below.
			# Example 13-Save offers a slightly better, object oriented solution to build upon this example 
			# (delegating save and load to the other nodes, the Save.gd script being only responsible to save and load on/from the disk)
			var val = _config_file.get_value(section,key)
			_settings[section][key] = val
			# Printing the values for debug purposes
			#print("%s: %s" % [key, val])
	if initial:
		_settings_initial = _settings
	return LOAD_SUCCESS

# Checks if settings are different than settings when initially started
func check_changed():
	if _settings != _settings_initial:
		return true
	else:
		return false

# Resets settings to default
func reset_settings():
	_settings = _settings_default
	save_settings(_settings)
	# Change keybind UI to default values, call load_keybinds?()

# Resets settings to before changed
func discard_settings():
	_settings = _settings_initial
	# Change keybind UI to initial values, call load_keybinds?()

func get_setting(category, key):
	return _settings[category][key]

func set_setting(category, key, value):
	_settings[category][key] = value

func load_keybinds():
	print("Loading keybinds")
	print(_settings)
	for control in _settings["Controls"]:
		if control != "SkillLayout":
			print(_settings["Controls"][control])
