extends Node2D

##### This is a client node that is created as a wrapper for all nodes/pawns under it.
# The name of the node will be the player's network ID so unique actions and control can be delegated to the local player only

# Tracks whether the client node is locally controlled or not
var control

# Load player node
var player_scene = preload("res://Pawn/Player.tscn")

# On call, instantiate and create a player node for the client.
func startGameCharacter():
	
	# Create a player scene as a child and attach
	var player = player_scene.instance()
	
	# Remove the initial camera node
	if has_node("/root/environment/Camera"):
		get_node("/root/environment/Camera").queue_free()
	
	# Set variables to be passed to player node
	player.control   = control
	player.clientName = name

	# Instantiate the player node
	add_child(player)
	player.initialize()
