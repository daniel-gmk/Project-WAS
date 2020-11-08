extends Node2D

##### This node handles minion location selection and associated UI

### Main Variables
# Tracks the calling player node
var player_node

# Tracks whether this node is initialized
var initialized = false

### Minion Select Variables
# Tracks max distance allowed to summon a minion from player vicinity
var maxDistance
# Tracks the minion being summoned
var minionType

func initialize(playerNode):
	player_node = playerNode
	initialized = true

# Called every frame
func _process(delta):
	if initialized:
		# Sets cursor location as free movement within the summon distance but clamped within the distance when mouse is outside
		$Sprite.position = to_local(get_global_mouse_position()).clamped(maxDistance)

# Upon input
func _input(event):
	if initialized and event.is_action_pressed("shoot"):
		# If the spot is available for teleporting, send instructions to player node to teleport
		if $Sprite.get_node("MinionSelectCursorPhysics").get_overlapping_bodies().size() == 0:
			call_deferred("minionClicked")

# Sets size of the UI and summon distance
func setSize(size, minionSize):
	$SelectLocation.scale = Vector2(size/$SelectLocation.texture.get_size().x, size/$SelectLocation.texture.get_size().y)
	$Sprite.scale = Vector2(minionSize/$Sprite.texture.get_size().x, minionSize/$Sprite.texture.get_size().y)
	maxDistance = size/2

# Calls RPC to calling player's node to summon minion
func minionClicked():
	if get_tree().is_network_server():
		if player_node.server_controlled:
			player_node.addMinionAsServer(minionType, $Sprite.global_position)
			player_node.removeMinionSelectLocation(false)
	else:
		player_node.addMinionToServer(minionType, $Sprite.global_position)
		player_node.removeMinionSelectLocation(false)
