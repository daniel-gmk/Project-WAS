extends Node2D

# Track if actions are allowed at all
var allowActions = false

func showSpriteOnly():
	$Sprite.visible = true

func show():
	$Sprite.visible = true
	if has_node("../HealthManager"):
		get_node("../HealthManager").immortal = false
		get_node("../HealthManager").enableDamageCollision()
	# Re-Enable collisions
	get_parent().enableCollision()

func hide():
	$Sprite.visible = false
	if has_node("../HealthManager"):
		get_node("../HealthManager").immortal = true
		get_node("../HealthManager").disableDamageCollision()
	# Disable Collisions
	get_parent().disableCollision()

# Instructions for freezing character
func freeze():
	allowActions = false
	get_parent().allowMovement = false
	if has_node("../AttackManager"):
		# Reset attack charge
		get_node("../AttackManager").resetAttack()

# Instructions for unfreezing AND resetting character values (jumping, attacking, etc)
func reset():
	allowActions = true
	get_parent().allowMovement = true
	# Reset physics
	get_parent().resetPhysics()

func flipSprite(vel):
	if vel >= 1:
		$Sprite.flip_h = false
	elif vel <= -1:
		$Sprite.flip_h = true
