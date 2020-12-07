extends Control


export var character_image_path : NodePath
var character_image

export var character_name_path : NodePath
var character_name

export var character_description_path : NodePath
var character_description

# Character data stored locally
export var characterdata_file_path = "res://GUI/Character-Selection/CharacterData.json"
# Extracted Character data to local memory
var character_data

var selected_character

# Called when the node enters the scene tree for the first time.
func _ready():
	
	character_name = get_node(character_name_path)
	character_description = get_node(character_description_path)
	character_image = get_node(character_image_path)
	
	var configFileNode = get_node("/root/GlobalConfigFile")
	selected_character = configFileNode.get_setting("Character", "Selected")

	# Load local skill data file
	var file = File.new()
	if file.open(characterdata_file_path, file.READ) != OK:
		print("error opening file")
		return
	var file_text = file.get_as_text()
	file.close()
	var file_parse = JSON.parse(file_text)
	if file_parse.error != OK:
		print("error parsing file")
		return
	character_data = file_parse.result
	
	set_character_data()

func set_character_data():
	character_name.text = character_data[str(selected_character)]["Name"]
	character_description.text = character_data[str(selected_character)]["Description"]
	# Replace image
	#print(character_data[str(selected_character)]["ProfileDir"])

func _on_TestCharacter_pressed():
	selected_character = 0
	var configFileNode = get_node("/root/GlobalConfigFile")
	configFileNode.set_setting("Character", "Selected", selected_character)
	configFileNode.save_settings(configFileNode._settings)
	
	set_character_data()
