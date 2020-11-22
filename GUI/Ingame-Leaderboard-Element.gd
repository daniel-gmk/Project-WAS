extends MarginContainer

##### This node handles each individual player's score element within the scoreboard

# Tracks whether the node is initialized/started
var initialized = false

# Tracks the local client's player node
var owningPlayer

# Path and node to player icon for profile picture display
export var playerIconPath : NodePath
var playerIcon

# Path and node to player name display
export var playerNamePath : NodePath
var playerName

# Path and node to player's score display
export var playerScorePath : NodePath
var playerScore

# Path and node to player's kills display
export var playerKillsPath : NodePath
var playerKills

# Path and node to player's assists display
export var playerAssistsPath : NodePath
var playerAssists

# Node to player's mute button display
var muteButton

# Node to player's ping display
var ping

# Tracks colors to set based on alive/dead or local player
var selfColor = Color("3da02f")
var otherColor = Color("888ab0")
var deadSelfColor = Color("5c5c5c")
var deadOtherColor = Color("282828")

# Called when node is initialized
func initialize(player):
	# Set nodes
	owningPlayer = player
	playerIcon = get_node(playerIconPath)
	playerName = get_node(playerNamePath)
	playerScore = get_node(playerScorePath)
	playerKills = get_node(playerKillsPath)
	playerAssists = get_node(playerAssistsPath)
	muteButton = get_node("HBoxContainer/MuteButton")
	ping = get_node("HBoxContainer/Ping")
	
	# Sets initial text and color
	playerName.text = owningPlayer.clientName
	if owningPlayer.clientName == str(get_tree().get_network_unique_id()):
		updateColor(selfColor)
	else:
		updateColor(otherColor)

	# Testing random scores to see if sorting works
	#var rng = RandomNumberGenerator.new()
	#rng.randomize()
	#var my_random_number = rng.randf_range(0.0, 1000.0)
	#playerScore.text = str(my_random_number)

	# Set as loaded
	initialized = true

# Sets/updates the element's color
func updateColor(color):
	get_node("ColorRect").color = color

# Sets/updates the score
func updateScore(score):
	playerScore.text = str(score)

# Sets/updates the kills
func updatePlayerKills(kills):
	playerKills.text = str(kills)

# Sets/updates the assists
func updatePlayerAssists(assists):
	playerAssists.text = str(assists)
