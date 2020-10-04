extends Node2D

# Allow setting attack projectile 
# Track scene type of explosion effect
export var explosion_scene : PackedScene
# Called when the node enters the scene tree for the first time.

func _ready():
	# Don't show any GUI elements to the server
	if get_tree().is_network_server():
		# Set camera focus to player
		$ServerCamera.control = true
		var camera = $ServerCamera
		camera.root = self
		camera.playerOwner = self
		camera.make_current()
	else:
		$ServerCamera.queue_free()

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
