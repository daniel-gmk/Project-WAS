extends Control

export var attacks_container_path : NodePath
var attacks_container

var configFileNode
var selected_character
var selected_character_attacks

func _ready():
	attacks_container = get_node(attacks_container_path)

	# Load config file info
	configFileNode = get_node("/root/GlobalConfigFile")
	selected_character = configFileNode.get_setting("Character", "Selected")
	selected_character_attacks = configFileNode.get_setting("Character", str(selected_character))["Attacks"]

	var counter = 0
	for child in attacks_container.get_children():
		child.get_node("Label").text = selected_character_attacks[counter]
		counter += 1

func _on_ReturnButton_pressed():
	get_tree().change_scene("res://GUI/Character-Selection/Character-Select.tscn")

func _on_AttacksButton_pressed():
	get_tree().change_scene("res://GUI/Skill-Selection/Attack-Select.tscn")
