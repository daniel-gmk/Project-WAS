extends Node2D

##### This node handles teleport location selection and associated UI

# Tracks size of the teleporting node
var entitySize

# Called when node loads
func _ready():
	$TeleportCamera.initialize(get_parent())

# Every frame set the position to the mouse
func _process(delta):
	$Sprite.position = get_global_mouse_position()

# If the spot is available for teleporting, send instructions to player node to teleport
func _input(event):
	if event.is_action_pressed("shoot") and !get_parent().menuPressed and get_parent().get_node("TeleportManager").serverCompletedResponse:
		# Check if location is already occupied by a node, then teleport above the node and make hole in terrain if necessary
		if $Sprite.get_node("EnvironmentArea2D").get_overlapping_bodies().size() == 0:
			if $Sprite.get_node("EntityArea2D").get_overlapping_bodies().size() > 0:
				# Set new location above the existing node and pass to clickedTeleport
				var ePos = Vector2($Sprite.position.x, $Sprite.position.y + entitySize.y)
				if get_tree().is_network_server():
					if get_parent().server_controlled:
						get_node("/root/1/").reposition_entity_serverCall(ePos, entitySize)
						call_deferred("clickedTeleport", ePos)
				else:
					get_node("/root/1/").reposition_entity_ToServer(ePos, entitySize)
					call_deferred("clickedTeleport", ePos)
			else:
				call_deferred("clickedTeleport", $Sprite.position)

# Sends teleport location and request to Teleport Manager
func clickedTeleport(pos):
	if get_tree().is_network_server() and get_parent().server_controlled:
		get_parent().get_node("TeleportManager").requestTeleportAsServer(pos)
		get_parent().get_node("TeleportManager").serverCompletedResponse = false
	else:
		get_parent().get_node("TeleportManager").requestTeleportToServer(pos)
		get_parent().get_node("TeleportManager").serverCompletedResponse = false

# Makes child camera the current camera in scene
func setCamera():
	$TeleportCamera.make_current()

# Clears child camera as current camera in scene
func clearCamera():
	$TeleportCamera.clear_current()

# Moves camera to center of map
func setCameraLocation(map_center_location):
	$TeleportCamera.mainPosition = map_center_location
	$TeleportCamera.position = map_center_location
