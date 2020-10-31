extends Node2D

# Allow setting attack projectile 
# Track scene type of explosion effect
export var explosion_scene : PackedScene
# Called when the node enters the scene tree for the first time.
# Variables passed to player node
var player_id
var control
# Load player node
var player_scene = preload("res://Pawn/Player.tscn")

func _process(delta):
	if get_tree().is_network_server():
		var triggerInitialTeleport = true
		var node_group = get_tree().get_nodes_in_group("TeleportManagers")
		if node_group.size() > 0:
			for node in node_group:
				if node.initialTeleport:
					triggerInitialTeleport = false
			if triggerInitialTeleport:
				for node in node_group:
					node.concludeTeleportAsServer()
					node.initialTeleport = false
					node.remove_from_group("TeleportManagers")

# On call, instantiate and create a player node for the client.
func startGameCharacter(serverControlled):
	var player = player_scene.instance()
	
	player.player_id = player_id
	player.control   = control

	if serverControlled:
		get_node("/root/environment/Camera").queue_free()
		player.server_controlled = true

	# Instantiate the character
	add_child(player)

# Remote function called by server to also execute terrain destruction but from server's perspective instead
# of client's perspective as an authoritative approach.
func broadcastExplosionServer(pos):
	rpc("broadcastExplosionRPC", pos)
	broadcastExplosion(pos)

# Server calls explosion to all clients
remote func broadcastExplosionRPC(pos):
	broadcastExplosion(pos)
	
# Clients execute explosion locally
func broadcastExplosion(pos):
	# Display explosion animation
	var explosion = explosion_scene.instance()
	explosion.global_position = pos
	
	# Explosion added to our parent, as we'll free ourselves.
	# If we attached the explosion to ourself it'd get free'd as well,
	# which would make them immediately vanish.
	get_parent().add_child(explosion)

# Calls destruction to clients on only the nodes with destructible attached
func destroyTerrainServerRPC(terrainChunks, pos, rad):
	for terrain_chunk in terrainChunks:
		if terrain_chunk.get_parent().has_method("destroy"):
			terrain_chunk.get_parent().destroyRPCServer(pos, rad)
			terrain_chunk.get_parent().destroy(pos, rad)
