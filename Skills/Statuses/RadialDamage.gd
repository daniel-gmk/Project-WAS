extends Area2D

# Track damage dealt, this is passed from the projectile/spell
var damage
# Tracks size of the damage AoE to determine who will have damage distributed to them
var size
# Track if there is flat damage dealt as long as within range of explosion, or if there is falloff from the center.
# The center leading up to 40% the radius will consist of max damage, but from there it will fall off. The terrain
# damage will also only be 70% of the total size.
var damage_falloff
# Tracks whether to ignore damage and collision to the caster (useful for certain attacks)
var ignoreCaster
# Keeps track of who casted the spell for ignoreCaster
var casterID

var knockback_force
var knockback_dropoff

# Passes the size variable to child so the collision circle is appropriately sized
func setSize(val):
	size = val
	$RadialShape.setSize(val)

# Called from projectile to detect all overlapping nodes and deal appropriate damage
func setExplosion():
	# This buffers/waits for two physics frames because the way godot works is that a Physics handler flushes out data
	# and it takes a frame or two to do that. Apparently it needs to do that or else this won't detect anything.
	# Remember to yield two frames for clients too, or at least explore if this builds up over the game and causes desync
	# Since only the server will buffer 2 frames every explosion and not the client
	yield(get_parent().get_tree(), "physics_frame")
	yield(get_parent().get_tree(), "physics_frame")
	
	# Retrieve an array of all overlapping entities
	var overlap_areas = get_overlapping_areas()
	# Apply for all entities overlapped
	for area in overlap_areas:
		# Only affect players since only players have this child node, filter out terrain
		if area.get_name() == "DamageCollisionArea":
			# Get radius of entity's collisionshape2D. Only works with Circle Collision Shapes
			var entitySize = area.get_node("DamageCollision").shape.radius
			# Consider the edge of the player's collision shape (circle) instead of the center, because
			# it shouldn't matter whether the explosion is overlapping your center or your edge.
			var totalDistance = area.global_position.distance_to(global_position) - (entitySize)
			# Resulting damage after calculating ignoreCaster, damage falloff, etc
			var calculatedDamage

			# If ignoreCaster is enabled and you're the caster, don't deal damage
			if ignoreCaster and area.get_parent().get_parent() == casterID:
				calculatedDamage = 0
			else:
				# Calculate falloff if damage falloff is enabled
				if damage_falloff:
					# If you're within the epicenter to 40% the radius, deal full damage
					if totalDistance <= (size * 0.4):
						calculatedDamage = damage
					else:
						# Calculate falloff if outside of the center to 40% range
						calculatedDamage = damage - ((totalDistance/size) * damage)
				else:
					# Deal damage with static value
					calculatedDamage = damage

			# Now that damage is calculated, pass this information to the server and have it pass damage to all clients
			area.get_parent().serverBroadcastDamageRPC(calculatedDamage)

		elif area.get_name() == "ProjectileImpulseArea":
			if !(ignoreCaster and area.get_parent() == casterID):
				if knockback_dropoff:
					var entitySize = area.get_node("ImpulseCollision").shape.radius
					# Consider the edge of the player's collision shape (circle) instead of the center, because
					# it shouldn't matter whether the explosion is overlapping your center or your edge.
					var totalDistance = area.global_position.distance_to(global_position) - (entitySize)
					var calculatedForce
					if totalDistance <= (size * 0.4):
						calculatedForce = knockback_force
						
					else:
						# Calculate falloff if outside of the center to 40% range
						calculatedForce = knockback_force - ((totalDistance/size) * knockback_force)
					knockback_force = calculatedForce
				area.get_parent().applyForceServer(global_position, knockback_force, knockback_dropoff)

	queue_free()
