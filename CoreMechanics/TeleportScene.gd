extends Node2D

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

# Every frame set the position to the mouse
func _process(delta):
	$Sprite.position = get_global_mouse_position()
	get_node("TeleportCamera/CanvasLayer/TeleportUI/Label").text = str(stepify(get_parent().get_node("TeleportManager").teleportSelectPenaltyTimer.get_time_left(), 0.1))
	get_node("TeleportCamera/CanvasLayer/TeleportUI/TextureProgress").value = get_parent().get_node("TeleportManager").teleportSelectPenaltyTimer.get_time_left()

# If the spot is available for teleporting, send instructions to player node to teleport
func _input(event):
	if event.is_action_pressed("shoot") and get_node("../TeleportManager").serverCompletedResponse:
		if $Sprite.get_node("Area2D").get_overlapping_bodies().size() == 0:
			get_parent().get_node("TeleportManager").requestTeleportToServer($Sprite.position)
			get_node("../TeleportManager").serverCompletedResponse = false
