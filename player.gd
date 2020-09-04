extends Node2D

### Root Player component. Most functions, movement, controls, etc are handled in playerPhysicsBody, but this node controls camera when not focused on player and set values for children

var control   = false
var player_id = 0
var root      = false
var console   = false

func _ready():
	# Don't show any GUI elements to the server
	if get_tree().is_network_server():
		$PlayerCamera.queue_free()
		if control:
			$playerPhysicsBody.control = control
			$playerPhysicsBody.player_id = player_id
	else:
		# Pass variables to children only if local player
		if control:
			$playerPhysicsBody.control = control
			$playerPhysicsBody.player_id = player_id
			$playerPhysicsBody.initiate_ui()
	
			# Set camera focus to player
			$PlayerCamera.control = control
			var camera = $PlayerCamera
			camera.root = self
			camera.playerOwner = $playerPhysicsBody
			camera.make_current()
			camera.changeToPlayerOwner()
		else:
			# remove UI for other players
			$PlayerCamera.get_node("GUI").queue_free()
