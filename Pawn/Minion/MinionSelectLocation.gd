extends Node2D

var maxDistance
var minionType

func setSize(size, minionSize):
	$SelectLocation.scale = Vector2(size/$SelectLocation.texture.get_size().x, size/$SelectLocation.texture.get_size().y)
	$Sprite.scale = Vector2(minionSize/$Sprite.texture.get_size().x, minionSize/$Sprite.texture.get_size().y)
	maxDistance = size/2

func _process(delta):
	$Sprite.position = to_local(get_global_mouse_position()).clamped(maxDistance)

# If the spot is available for teleporting, send instructions to player node to teleport
func _input(event):
	if event.is_action_pressed("shoot"):
		if $Sprite.get_node("MinionSelectCursorPhysics").get_overlapping_bodies().size() == 0:
			call_deferred("minionClicked")

func minionClicked():
	if get_tree().is_network_server():
		if get_parent().get_parent().server_controlled:
			get_parent().get_parent().addMinionAsServer(minionType, $Sprite.global_position)
			get_parent().get_parent().removeMinionSelectLocation(false)
	else:
		get_parent().get_parent().addMinionToServer(minionType, $Sprite.global_position)
		get_parent().get_parent().removeMinionSelectLocation(false)
