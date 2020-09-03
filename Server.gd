extends Node2D

# Allow setting attack projectile 
# Track scene type of explosion effect
export var explosion_scene : PackedScene
# Plan to replace this twice, once with basic attack, other with dynamic spellbook selection
export var weapon_projectile : PackedScene
# Called when the node enters the scene tree for the first time.

# Has the server calculate fall damage and distribute that information to clients
remote func calculateFallDamageServer(fallHeight, fallDamageHeight, fallDamageRate, sender):
	var resultingDamage = (fallHeight - fallDamageHeight) * fallDamageRate
	if resultingDamage < 0:
		print("Error, damage is negative when they should be taking damage")
	else:
		get_parent().get_node(sender).get_node("player").get_node("playerPhysicsBody").takeDamage(resultingDamage)
		get_parent().get_node(sender).get_node("player").get_node("playerPhysicsBody").rpc("takeDamageRPC", resultingDamage)

# Send data of a shot projectile and simulate across server to other players
remote func summonProjectileServer(startpos, position2, speed, attack_power, attack_scale, isServer, damage, explosion_radius, damage_falloff, ignoreSelf, sender):
	# If server
	summonProjectile(startpos, position2, speed, attack_power, attack_scale, true, damage, explosion_radius, damage_falloff, ignoreSelf, sender)
	# Loop through clients and launch projectile to each
	rpc("summonProjectileRPC", startpos, position2, speed, attack_power, attack_scale, false, 0, 0, false, ignoreSelf, sender)

# Send data of a shot projectile and simulate across server to other players
remote func summonProjectileRPC(startpos, position2, speed, attack_power, attack_scale, isServer, damage, explosion_radius, damage_falloff, ignoreSelf, sender):
	var physicsbody = get_parent().get_node(str(sender)).get_node("player").get_node("playerPhysicsBody")
	if physicsbody.player_id != sender:
		summonProjectile(startpos, position2, speed, attack_power, attack_scale, false, 0, 0, false, ignoreSelf, sender)

# Launches projectile/attack
func summonProjectile(startpos, position2, speed, attack_power, attack_scale, isServer, damage, explosion_radius, damage_falloff, ignoreSelf, sender):
	# Spawn instance of projectile node
	var new_projectile := weapon_projectile.instance() as RigidBody2D
	# Initialize other variables for Projectile, details on the variables are on Projectile.gd
	new_projectile.damage = damage
	new_projectile.explosion_radius = explosion_radius
	new_projectile.damage_falloff = damage_falloff
	new_projectile.ignoreCaster = ignoreSelf
	new_projectile.casterID = get_node("/root/").get_node(str(sender))
	if ignoreSelf: 
		new_projectile.add_collision_exception_with(self)
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
func broadcastExplosionServer(pos, rad):
	rpc("broadcastExplosionRPC", pos, rad)
	broadcastExplosion(pos, rad)

# Server calls explosion to all clients
remote func broadcastExplosionRPC(pos, rad):
	broadcastExplosion(pos, rad)
	
# Clients execute explosion locally
func broadcastExplosion(pos, rad):
	# Damage the terrain from the client side
	get_tree().call_group("destructibles", "destroy", pos, rad)
	# Display explosion animation
	var explosion = explosion_scene.instance()
	explosion.global_position = pos
	
	# Explosion added to our parent, as we'll free ourselves.
	# If we attached the explosion to ourself it'd get free'd as well,
	# which would make them immediately vanish.
	get_parent().add_child(explosion)
