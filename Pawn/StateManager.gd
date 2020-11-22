extends Node2D

##### This node handles the state of the parent node, is required for all nodes
# For example, to manage whether the node is hidden, paused, etc

# Track if actions are allowed at all
export var allowActions = false

# Show the sprite only
func showSpriteOnly():
	$Sprite.visible = true

# Put the pawn back into play
func show():
	$Sprite.visible = true
	if get_parent().has_node("HealthManager"):
		get_parent().get_node("HealthManager").immortal = false
		get_parent().get_node("HealthManager").enableDamageCollision()
	# Re-Enable collisions
	get_parent().enableCollision()

# Remove the pawn from play
func hide():
	$Sprite.visible = false
	if get_parent().has_node("HealthManager"):
		get_parent().get_node("HealthManager").immortal = true
		get_parent().get_node("HealthManager").disableDamageCollision()
	# Disable Collisions
	get_parent().disableCollision()

# Pausing a pawn in place
func freeze():
	allowActions = false
	get_parent().allowMovement = false
	if get_parent().has_node("AttackManager"):
		# Reset attack charge
		get_parent().get_node("AttackManager").resetAttack()

# Resuming a pawn from pause AND resetting character values (jumping, attacking, etc)
func reset(): # Should probably be renamed to unfreeze instead
	allowActions = true
	get_parent().allowMovement = true
	# Reset physics
	get_parent().resetPhysics()

# Change the sprite direction
func flipSprite(vel):
	if vel > 0:
		$Sprite.flip_h = false
	elif vel < 0:
		$Sprite.flip_h = true
