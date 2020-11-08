extends Node2D

##### This node allows health capabilities for the parent node that it is attached to

### Main
# Track the owning player's node
var player_node

### Health
# Health minimum
var minHealth = 0
# Health maxmimum
export var maxHealth = 10000
# Current health
var health
# Immortal, can be bypassed by very few exceptions but will avoid most types of ingame damage
var immortal = false
# If immune to fall damage only
export var fallDamageImmunity = false

### HUD
# Track the HUD component path
var GUI_node
# Use the path to grab the Main player's Health bar (Child Component of HUD) as a var
var main_health_bar_root
# Use the path to grab the Main player's Health bar value text (Child Component of Health bar) as a var
var main_health_bar_text
# Use the path to grab mini health bars over all other entities
var mini_health_bar_root

func initialize():
	# Set owning player's node
	player_node = get_parent().player_node
	# Set health
	health = maxHealth
	# If self MainPawn
	if get_parent().MainPawn and player_node.control:
		# Remove Mini HP Bar
		if has_node("MiniHPBar"):
			get_node("MiniHPBar").queue_free()
		# Set main HP bar
		GUI_node = player_node.get_node("PlayerCamera/CanvasLayer/GUI")
		main_health_bar_root = GUI_node.find_node("MainHealthBar")
		main_health_bar_text = main_health_bar_root.find_node("HealthValueText")
		initiate_main_health_ui()
	# For minions and all other player pawns, set mini HP bar
	elif has_node("MiniHPBar"):
		mini_health_bar_root = get_node("MiniHPBar")
		initiate_mini_health_ui()
	# Not entirely sure if this does anything but it sets collision monitoring on for the character to detect aoe damage
	$DamageCollisionArea.monitorable = true

# Handles when damage is taken
func takeDamage(damage, immortalBypass):
	if damage < 0:
		print("Error: Negative damage reported")
	if !immortal or immortalBypass:
		health -= damage
		#health = max(minHealth, health - damage)
		# Update health bar HUD
		if get_tree().get_network_unique_id() == int(player_node.clientName):
			if get_parent().MainPawn:
				main_health_bar_root.value = health
				main_health_bar_text.text = String(round(health))
		if has_node("MiniHPBar"):
			mini_health_bar_root.value = health
		# Dead if health falls below min value
		if health <= minHealth:
			death()

# Handles when dead, not implemented yet since gamemode should be created first
func death():
	print("I died")
	# Remember to cancel teleporting

#################################NETWORK FUNCTIONS

# Has the server calculate fall damage and distribute that information to clients
func calculateFallDamageServer(fallHeight, fallDamageHeight, fallDamageRate):
	var resultingDamage = (fallHeight - fallDamageHeight) * fallDamageRate
	if resultingDamage < 0:
		print("Error, damage is negative when they should be taking damage")
	elif !fallDamageImmunity:
		takeDamage(resultingDamage, false)
		rpc("takeDamageRPC", resultingDamage, false)

# Server receives call to locally execute damage and also replicate damage to clients
func serverBroadcastDamageRPC(damage, immortalBypass):
	takeDamage(damage, immortalBypass)
	rpc("takeDamageRPC", damage, immortalBypass)

# I abstracted takeDamage as a local call instead of just making it a remote function in case I want to make local
# calls down the road and not quite sure if I need to yet.
remote func takeDamageRPC(damage, immortalBypass):
	takeDamage(damage, immortalBypass)

#################################PHYSICS FUNCTIONS

# Enable damage collision so damage can be detected and applied from the physics side
func enableDamageCollision():
	get_node("DamageCollisionArea/DamageCollision").disabled = false

# Disable damage collision so damage cannot be detected and applied from the physics side
func disableDamageCollision():
	get_node("DamageCollisionArea/DamageCollision").disabled = true

#################################UI FUNCTIONS

# Helper function to hide Mini HP Bar
func hideMiniHPBar():
	if has_node("MiniHPBar"):
		get_node("MiniHPBar").visible = false

# Helper function to show Mini HP Bar
func showMiniHPBar():
	if has_node("MiniHPBar"):
		get_node("MiniHPBar").visible = true

# Set UI
func initiate_main_health_ui():
	# Set Health Bar
	main_health_bar_root.max_value = maxHealth
	main_health_bar_root.min_value = minHealth
	main_health_bar_root.value = health
	main_health_bar_text.text = String(health)
	
# Set UI
func initiate_mini_health_ui():
	# Set Health Bar
	mini_health_bar_root.max_value = maxHealth
	mini_health_bar_root.min_value = minHealth
	mini_health_bar_root.value = health
