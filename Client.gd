extends Node2D

# This is coding mistake #2 where instead of reorganizing/recreating player and playerPhysicsBody nodes, I just made another
# parent node, this, to make multiplayer instantiation work. Basically, this node exists, and when game start is initiated
# by the server, it spawns the player and corresponding child node playerPhysicsBody, so that it avoids rpc errors when
# all player characters are not loaded in yet. It converts asynchronous game start to synchronous game start, which I 
# wanted anyway. Down the road this should be replaced by player.

# Variables passed to player node
var player_id
var control

# Load player node
var player_scene = preload("res://player.tscn")

# On call, instantiate and create a player node for the client.
func startGameCharacter():
	var player = player_scene.instance()
	
	player.player_id = player_id
	player.control   = control
		
	# Instantiate the character
	add_child(player)
