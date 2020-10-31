extends Node2D

# Variables passed to player node
var player_id
var control

# Load player node
var player_scene = preload("res://Pawn/Player.tscn")

# On call, instantiate and create a player node for the client.
func startGameCharacter():
	if has_node("/root/environment/Camera"):
		get_node("/root/environment/Camera").queue_free()
	var player = player_scene.instance()
	
	player.player_id = player_id
	player.control   = control
		
	# Instantiate the character
	add_child(player)
