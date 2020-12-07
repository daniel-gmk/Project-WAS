extends Control


export var video_node_path : NodePath
var video_node

export var attack_slot_number_path : NodePath
var attack_slot_number
export var attack_slot_keybind_value_path : NodePath
var attack_slot_keybind_value

export var attack_description_path : NodePath
var attack_description
export var attack_name_path : NodePath
var attack_name

export var damage_rating_path : NodePath
var damage_rating
export var effect_rating_path : NodePath
var effect_rating
export var difficulty_rating_path : NodePath
var difficulty_rating

export var attack_options_container_path : NodePath
var attack_options_container

# Skill data stored locally
export var skilldata_file_path = "res://Skills/SkillData.json"
# Extracted skill data to local memory
var skill_data
# Character data stored locally
export var characterdata_file_path = "res://GUI/Character-Selection/CharacterData.json"
# Extracted Character data to local memory
var character_data

var selected_character
var selected_character_attacks

var configFileNode

var current_selected_attack_index = 0

# Called when the node enters the scene tree for the first time.
func _ready():
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
	selected_character_attacks = configFileNode.get_setting("Character", str(selected_character))["Attacks"]

	# Load Attack Options
	attack_options_container = get_node(attack_options_container_path)
	var attack_options = character_data[str(selected_character)]["AttackOptions"]
	var container_children = attack_options_container.get_children()
	var container_counter = 0
	for child_container in container_children:
		if container_counter < attack_options.size():
			child_container.get_node("ColorRect/SkillButton/AttackLabel").text = attack_options[container_counter]
			child_container.initialize(self, attack_options[container_counter], container_counter + 1)
			var toggled = selected_character_attacks.has(attack_options[container_counter])
			if toggled:
				child_container.toggle_on()
			# Set textureRect
			container_counter += 1
		else:
			break

	update_display()

func update_display():
	# Load display
	attack_slot_number = get_node(attack_slot_number_path)
	attack_slot_keybind_value = get_node(attack_slot_keybind_value_path)
	
	attack_slot_number.text = str(current_selected_attack_index + 1)
	attack_slot_keybind_value.text = OS.get_scancode_string(configFileNode.get_setting("Controls", "Skill" + str(current_selected_attack_index + 1)))
	
	# Load attack data text
	attack_description = get_node(attack_description_path)
	attack_description.text = skill_data[selected_character_attacks[current_selected_attack_index]]["Description"]
	
	attack_name = get_node(attack_name_path)
	attack_name.text = selected_character_attacks[current_selected_attack_index]
	
	# Load Attack Stats
	damage_rating = get_node(damage_rating_path)
	damage_rating.value = skill_data[selected_character_attacks[current_selected_attack_index]]["Damage_Rating"]
	effect_rating = get_node(effect_rating_path)
	effect_rating.value = skill_data[selected_character_attacks[current_selected_attack_index]]["Effect_Rating"]
	difficulty_rating = get_node(difficulty_rating_path)
	difficulty_rating.value = skill_data[selected_character_attacks[current_selected_attack_index]]["Difficulty_Rating"]

	# Load video
	video_node = get_node(video_node_path)
	video_node.stream = load("res://Skills/Video-Demos/" + selected_character_attacks[current_selected_attack_index] + ".webm")
	video_node.set_volume(0.0)
	video_node.play()

func skillButtonPressed(skill, placing):
	print(skill)
	print(placing)

func _on_VideoPlayer_finished():
	video_node.play()
