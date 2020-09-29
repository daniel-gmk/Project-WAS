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

func _process(delta):
	if get_tree().is_network_server():
		var triggerInitialTeleport = true
		var node_group = get_tree().get_nodes_in_group("TeleportManagers")
		if node_group.size() > 0:
			for node in node_group:
				if node != self and node.initialTeleport:
					triggerInitialTeleport = false
			if triggerInitialTeleport:
				for node in node_group:
					node.concludeTeleportAsServer()
					node.initialTeleport = false
					node.remove_from_group("TeleportManagers")

# Has the server calculate fall damage and distribute that information to clients
func calculateFallDamageServer(fallHeight, fallDamageHeight, fallDamageRate, sender):
	var resultingDamage = (fallHeight - fallDamageHeight) * fallDamageRate
	if resultingDamage < 0:
		print("Error, damage is negative when they should be taking damage")
	else:
		get_node("/root/").get_node(str(sender)).get_node("Player").get_node("MainPawn").get_node("HealthManager").takeDamage(resultingDamage)
		get_node("/root/").get_node(str(sender)).get_node("Player").get_node("MainPawn").get_node("HealthManager").rpc("takeDamageRPC", resultingDamage)

# Send data of a shot projectile and simulate across server to other players
remote func summonProjectileServer(startpos, position2, speed, attack_power, attack_scale, isServer, damage, explosion_radius, damage_falloff, ignoreSelf, sender, skill_type):
	# If server
	summonProjectile(startpos, position2, speed, attack_power, attack_scale, true, damage, explosion_radius, damage_falloff, ignoreSelf, sender, skill_type)
	# Loop through clients and launch projectile to each
	rpc("summonProjectileRPC", startpos, position2, speed, attack_power, attack_scale, false, 0, 0, false, ignoreSelf, sender, skill_type)

# Send data of a shot projectile and simulate across server to other players
remote func summonProjectileRPC(startpos, position2, speed, attack_power, attack_scale, isServer, damage, explosion_radius, damage_falloff, ignoreSelf, sender, skill_type):
	var physicsbody = get_parent().get_node(str(sender)).get_node("Player").get_node("MainPawn")
	if physicsbody.get_parent().player_id != sender:
		summonProjectile(startpos, position2, speed, attack_power, attack_scale, false, 0, 0, false, ignoreSelf, sender, skill_type)

# Launches projectile/attack
func summonProjectile(startpos, position2, speed, attack_power, attack_scale, isServer, damage, explosion_radius, damage_falloff, ignoreSelf, sender, skill_type):
	# Spawn instance of projectile node
	var scene_dir = "res://Skills/" + skill_type + ".tscn"
	var projectile_scene = load(scene_dir)
	var new_projectile := projectile_scene.instance() as RigidBody2D
	# Initialize other variables for Projectile, details on the variables are on Projectile.gd
	new_projectile.damage = damage
	new_projectile.explosion_radius = explosion_radius
	new_projectile.damage_falloff = damage_falloff
	new_projectile.ignoreCaster = ignoreSelf
	new_projectile.casterID = get_node("/root/").get_node(str(sender))
	new_projectile.add_collision_exception_with(get_node("/root/").get_node(str(sender)).get_node("Player").get_node("MainPawn"))
	# Apply reticule position as projectile's starting position
	new_projectile.global_position = startpos
	# Apply force/velocity to the projectile to launch based on charge power and direction of aim
	new_projectile.linear_velocity = (startpos - position2) * speed * (attack_power * attack_scale)
	# Projectile is server so set variable
	new_projectile.server = isServer
	# Bring the configured projectile into the scene/world
	get_parent().get_node("environment").add_child(new_projectile)

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
