extends RigidBody2D

### Root node for projectile, handling behavior when hitting entities

# Track size of terrain damage radius, allow it to be set
var explosion_radius
# Track scene type of explosion effect
export var explosion_scene : PackedScene
# Track radial damage scene to create aoe effect and have it handle/apply damage
var radialDamage = load("res://RadialDamage.tscn")
# Track damage dealt, this is passed from the caster/player
var damage
# Track if there is flat damage dealt as long as within range of explosion, or if there is falloff from the center.
# The center leading up to 40% the radius will consist of max damage, but from there it will fall off. The terrain
# damage will also only be 70% of the total size.
var damage_falloff
# Tracks whether to ignore damage and collision to the caster (useful for certain attacks)
var ignoreCaster
# Keeps track of who casted the spell for ignoreCaster
var casterID
# Tracks whether the projectile is local to the client or from the server
var server

func _on_Projectile_body_entered(_body):
	# Only if this is the server's projectile
	if server:
		var newRadius = explosion_radius
		# Hole left in terrain is relatively smaller than explosion itself if damage falloff is enabled
		if damage_falloff == true:
			newRadius = 0.7 * explosion_radius
		
		# Damage the terrain from the server side
		get_tree().call_group("destructibles", "destroy", global_position, newRadius)
		# Replicate terrain damage to clients. This is to keep the server as authority and prevent desync of terrain
		rpc("destroyTerrainRPC", global_position, newRadius)
		
		# Summon a radial damage node, which will issue the damage.
		var rd = radialDamage.instance()
		# Set and pass variables from projectile to damage node
		rd.position = position
		rd.damage = damage
		rd.damage_falloff = damage_falloff
		rd.casterID = casterID
		rd.ignoreCaster = ignoreCaster
		# Add the child with a deferred call approach to avoid collision/propogation errors
		get_parent().call_deferred("add_child", rd)
		# Ensures that the radial damage node is detecting collision
		rd.monitoring = true
		# Setting size of the explosion so that overlapping nodes get detected
		rd.setSize(explosion_radius)
		# Calls in deferred fashion to avoid collision/propogation errors, initiates the scan to detect overlapping nodes and issue damage
		rd.call_deferred("setExplosion")
		
		# Display explosion animation
		var explosion = explosion_scene.instance()
		explosion.global_position = position
		
		# Explosion added to our parent, as we'll free ourselves.
		# If we attached the explosion to ourself it'd get free'd as well,
		# which would make them immediately vanish.
		get_parent().add_child(explosion)
		
		# Self terminate after all this is over. Again, this is only for the server's projectile.
		# There is also a "fake" projectile sent for clients for user experience
		queue_free()

# Remote function called by server to also execute terrain destruction but from server's perspective instead
# of client's perspective as an authoritative approach.
remote func destroyTerrainRPC(pos, rad):
	# Damage the terrain from the client side
	get_tree().call_group("destructibles", "destroy", pos, rad)
	# Display explosion animation
	var explosion = explosion_scene.instance()
	explosion.global_position = pos
	
	# Explosion added to our parent, as we'll free ourselves.
	# If we attached the explosion to ourself it'd get free'd as well,
	# which would make them immediately vanish.
	get_parent().add_child(explosion)
	
	# Self terminate after all this is over. Server calls for the client's projectile to be destroyed. If there
	# is ever an error from the server, this might not disappear and just bounce around. Hope this doesn't happen... 
	queue_free()
