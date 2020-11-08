extends Node2D

##### Manages certain abstracted events for server-client RPC calls, but also doubles as P2P server's local client

# Tracks whether the client node is locally controlled or not
var control
# Load player node
var player_scene = preload("res://Pawn/Player.tscn")

# Loads terrain damage node that destroys terrain
var terrainDamage = load("res://Environment/TerrainDamage.tscn")
# Causes explosions
export var explosion_scene : PackedScene

# Called every tick
func _process(delta):
	# Server control of synchronized teleporting on initial game start
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
	
	# Create a player scene as a child and attach
	var player = player_scene.instance()

	# Remove the initial camera node and set P2P server setting for local client access
	if serverControlled:
		get_node("/root/environment/Camera").queue_free()
		player.server_controlled = true
	
	# Set variables to be passed to player node
	player.control   = control
	player.clientName = name

	# Instantiate the character
	add_child(player)
	player.initialize()

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

# Wrapper RPC for client to call server
func reposition_entity_ToServer(entityPos, es):
	rpc_id(1, "reposition_entity_server", entityPos, es)

# Wrapper RPC for when server is called from client to call serverCall (below)
remote func reposition_entity_server(entityPos, es):
	reposition_entity_serverCall(entityPos, es)

# Wrapper RPC for server to call RPC and locally
func reposition_entity_serverCall(entityPos, es):
	rpc("reposition_entity_RPC", entityPos, es)
	reposition_entity(entityPos, es)

# Wrapper RPC from server to clients to call locally
remote func reposition_entity_RPC(entityPos, es):
	reposition_entity(entityPos, es)

# Repositions an entity (player main pawn or minion) and sets explosion
func reposition_entity(entityPos, es):
	var td = terrainDamage.instance()
	td.position = entityPos
	# Add the child with a deferred call approach to avoid collision/propogation errors
	get_parent().call_deferred("add_child", td)
	td.monitoring = true
	td.setSize(max(es.x, es.y))
	td.call_deferred("setExplosion")
