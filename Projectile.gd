extends RigidBody2D

### Root node for projectile, handling behavior when hitting entities

export var explosion_radius : float = 20
export var explosion_scene : PackedScene
# Tracks whether the projectile is local to the client or from the server
var server = false

func _on_Projectile_body_entered(_body):
	# Only if this is the server's projectile
	if server:
		# Tell the destruction system that we're causing an explosion
		get_tree().call_group("destructibles", "destroy", global_position, explosion_radius)
		
	# Display explosion animation
	var explosion = explosion_scene.instance()
	explosion.global_position = position
	
	# Explosion added to our parent, as we'll free ourselves.
	# If we attached the explosion to ourself it'd get free'd as well,
	# which would make them immediately vanish.
	get_parent().add_child(explosion)

	queue_free()
