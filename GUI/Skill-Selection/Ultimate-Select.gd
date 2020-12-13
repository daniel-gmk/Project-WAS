extends Control

##### This node handles the menu that allows ultimate selection

### Nodes and Node Paths
export var save_menu_path : NodePath
var save_menu
export var video_node_path : NodePath
var video_node
export var keybind_node_path : NodePath
var keybind_node
export var ultimate_description_path : NodePath
var ultimate_description
export var ultimate_name_path : NodePath
var ultimate_name
export var damage_rating_path : NodePath
var damage_rating
export var effect_rating_path : NodePath
var effect_rating
export var difficulty_rating_path : NodePath
var difficulty_rating
export var ultimate_options_container_path : NodePath
var ultimate_options_container

### Data files

# Node for storing local settings
var configFileNode

# Skill data stored locally
export var skilldata_file_path = "res://Skills/SkillData.json"
# Extracted skill data to local memory
var skill_data

# Character data stored locally
export var characterdata_file_path = "res://GUI/Character-Selection/CharacterData.json"
# Extracted Character data to local memory
var character_data
# Attacks that the selected Character can perform
var ultimate_options

### Currently selected setting (the one being modified or set)

# The character that the player selected
var selected_character
# The attacks the player selected for the character in their local settings
var selected_character_ultimates
# Placing of the currently selected ultimate for the selected keybind
var current_selected_ultimate_index

# Tracks the button that is selected for choosing skills for the keybind
var selected_keybind_button
# Tracks the index/placing/ordering of the keybind button
var selected_keybind_index = 0
# Tracks the Godot keybind value for the currently selected keybind
var selected_keybind_value

### Ephemeral settings for settings in current menu

# Tracks the original mapping settings to track if settings changed
var original_mappings
# Tracks the current mappings/settings for keybind to skill
var mappings = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	# Set node
	save_menu = get_node(save_menu_path)
	
	# Load local skill data file
	var file = File.new()
	if file.open(skilldata_file_path, file.READ) != OK:
		print("error opening file")
		return
	var file_text = file.get_as_text()
	file.close()
	var file_parse = JSON.parse(file_text)
	if file_parse.error != OK:
		print("error parsing file")
		return
	skill_data = file_parse.result

	# Load local character data file
	if file.open(characterdata_file_path, file.READ) != OK:
		print("error opening file")
		return
	file_text = file.get_as_text()
	file.close()
	file_parse = JSON.parse(file_text)
	if file_parse.error != OK:
		print("error parsing file")
		return
	character_data = file_parse.result

	# Load config file info
	configFileNode = get_node("/root/GlobalConfigFile")
	selected_character = configFileNode.get_setting("Character", "Selected")
	selected_character_ultimates = configFileNode.get_setting("Character", str(selected_character))["Ultimates"]

	# Loading keybinds
	keybind_node = get_node(keybind_node_path)
	selected_keybind_button = keybind_node.get_node("Ultimate1")
	selected_keybind_button.disabled = true
	var index = 0
	for skillButton in keybind_node.get_children():
		if skillButton is Button:
			skillButton.index = index
			skillButton.keybind = configFileNode.get_setting("Controls", skillButton.name)
			skillButton.text = OS.get_scancode_string(configFileNode.get_setting("Controls", skillButton.name))
			skillButton.connect("pressed", self, "keybindButtonPressed", [skillButton])
			index += 1

	# Load Attack Options
	ultimate_options_container = get_node(ultimate_options_container_path)
	ultimate_options = character_data[str(selected_character)]["UltimateOptions"]
	var container_children = ultimate_options_container.get_children()
	var container_counter = 0
	var ultimate_counter = 0
	for child_container in container_children:
		if container_counter < ultimate_options.size():
			child_container.get_node("ColorRect/SkillButton/UltimateLabel").text = ultimate_options[container_counter]
			child_container.initialize(self, ultimate_options[container_counter], container_counter + 1)
			container_counter += 1
		else:
			break

	# Load whether attack is selected or not
	for ultimate in selected_character_ultimates:
		for child_container in container_children:
			var toggled = child_container.skillName == str(ultimate)
			if toggled:
				child_container.toggle_on()
				var keybind = OS.get_scancode_string(configFileNode.get_setting("Controls", "Ultimate" + str(ultimate_counter + 1)))
				child_container.keybind = keybind
				child_container.selectedSkillPlacing = ultimate_counter
				if ultimate_counter == 0:
					current_selected_ultimate_index = child_container.skillName
					selected_keybind_value = configFileNode.get_setting("Controls", "Ultimate" + str(ultimate_counter + 1))
				mappings[child_container.selectedSkillPlacing] = child_container
				child_container.keybindValue = configFileNode.get_setting("Controls", "Ultimate" + str(child_container.selectedSkillPlacing + 1))
				if child_container.bindLabel != null:
					child_container.bindLabel.text = keybind
					child_container.get_node("ColorRect/SkillButton/BindLabelDesc").visible = true
					child_container.bindLabel.visible = true
	
				ultimate_counter += 1
				break

	# Set original mappings to detect changes
	original_mappings = mappings.duplicate()

	# Update element state to reflect current settings
	update_display()

# Sets the display to reflect current/updated settings
func update_display():
	# Load attack data text
	ultimate_description = get_node(ultimate_description_path)
	ultimate_description.text = skill_data[current_selected_ultimate_index]["Description"]
	ultimate_name = get_node(ultimate_name_path)
	ultimate_name.text = current_selected_ultimate_index

	# Load Attack Stats
	damage_rating = get_node(damage_rating_path)
	damage_rating.value = skill_data[current_selected_ultimate_index]["Damage_Rating"]
	effect_rating = get_node(effect_rating_path)
	effect_rating.value = skill_data[current_selected_ultimate_index]["Effect_Rating"]
	difficulty_rating = get_node(difficulty_rating_path)
	difficulty_rating.value = skill_data[current_selected_ultimate_index]["Difficulty_Rating"]

	# Load video
	video_node = get_node(video_node_path)
	video_node.stream = load("res://Skills/Video-Demos/" + current_selected_ultimate_index + ".webm")
	video_node.set_volume(0.0)
	video_node.play()

# When skill button is pressed
func skillButtonPressed(skillButton):
	if !skillButton.toggled:
		replaceButton(mappings[selected_keybind_index], skillButton)

# When a new skill is selected it unbinds the old one and binds the new one
func replaceButton(oldButton, newButton):
	var keybind = OS.get_scancode_string(configFileNode.get_setting("Controls", "Ultimate" + str(oldButton.selectedSkillPlacing + 1)))
	# Disable old button/skill
	oldButton.toggle_off()
	oldButton.get_node("ColorRect/SkillButton/BindLabelDesc").visible = false
	oldButton.bindLabel.visible = false

	# Change settings from old to new skill
	mappings[selected_keybind_index] = newButton
	newButton.keybind = keybind
	newButton.keybindValue = configFileNode.get_setting("Controls", "Ultimate" + str(oldButton.selectedSkillPlacing + 1))
	newButton.selectedSkillPlacing = oldButton.selectedSkillPlacing
	current_selected_ultimate_index = newButton.skillName
	
	# Enable new button/skill
	newButton.toggle_on()
	newButton.get_node("ColorRect/SkillButton/BindLabelDesc").visible = true
	newButton.bindLabel.visible = true
	newButton.bindLabel.text = newButton.keybind
	
	# Update display to reflect changes
	update_display()

# New keybind is selected
func keybindButtonPressed(skillButton):
	selected_keybind_button.disabled = false
	selected_keybind_button = skillButton
	selected_keybind_value = skillButton.keybind
	selected_keybind_index = skillButton.index
	selected_keybind_button.disabled = true

func _on_Yes_pressed():
	exit()

func _on_No_pressed():
	save_menu.visible = false

func _on_VideoPlayer_finished():
	video_node.play()

func _on_ExitButton_pressed():
	if mappings.hash() != original_mappings.hash():
		save_menu.visible = true
	else:
		exit()

func _on_SaveButton_pressed():
	var newUltimates = []
	for keybind in mappings:
		newUltimates.append(mappings[keybind].skillName)
	original_mappings = mappings.duplicate()
	var newConfig = configFileNode.get_setting("Character", str(selected_character))
	newConfig["Ultimates"] = newUltimates
	configFileNode.set_setting("Character", str(selected_character), newConfig)
	configFileNode.save_settings(configFileNode._settings)

# Switches back to overall skill menu
func exit():
	get_tree().change_scene("res://GUI/Skill-Selection/Overall-Skill-Select.tscn")
