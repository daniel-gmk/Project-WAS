extends Node2D

### Health
var minHealth = 0
export var maxHealth = 10000
var health
var immortal = false
export var fallDamageImmunity = false

var player_node

### HUD
# Track the HUD component path
var GUI_node
# Use the path to grab the Main player's Health bar (Child Component of HUD) as a var
var main_health_bar_root
# Use the path to grab the Main player's Health bar value text (Child Component of Health bar) as a var
var main_health_bar_text

var mini_health_bar_root

func _ready():
	player_node = get_parent().get_parent()
	# Set health
	health = maxHealth
	if !get_tree().is_network_server():
		if get_parent().MainPawn and player_node.control:
			if has_node("MiniHPBar"):
				get_node("MiniHPBar").queue_free()
			GUI_node = player_node.get_node("PlayerCamera/CanvasLayer/GUI")
			main_health_bar_root = GUI_node.find_node("MainHealthBar")
			main_health_bar_text = main_health_bar_root.find_node("HealthValueText")
			initiate_main_health_ui()
		elif has_node("MiniHPBar"):
			mini_health_bar_root = get_node("MiniHPBar")
			initiate_mini_health_ui()
	# Not entirely sure if this does anything but it sets collision monitoring on for the character to detect aoe damage
	$DamageCollisionArea.monitorable = true

func enableDamageCollision():
	get_node("DamageCollisionArea/DamageCollision").disabled = false

func disableDamageCollision():
	get_node("DamageCollisionArea/DamageCollision").disabled = true

func hideHPBar():
	if has_node("MiniHPBar"):
		get_node("MiniHPBar").visible = false

func showHPBar():
	if has_node("MiniHPBar"):
		get_node("MiniHPBar").visible = true

# Handles when damage is taken
func takeDamage(damage):
	if damage < 0:
		print("Error: Negative damage reported")
	if !immortal:
		health -= damage
		# Update health bar HUD
		if get_tree().get_network_unique_id() == player_node.player_id:
			if get_parent().MainPawn:
				main_health_bar_root.value = health
				main_health_bar_text.text = String(round(health))
		if has_node("MiniHPBar") and !get_tree().is_network_server():
			mini_health_bar_root.value = health
		# Dead if health falls below min value
		if health <= minHealth:
			death()

# Handles when dead, not implemented yet since gamemode should be created first
func death():
	print("I died")

# Has the server calculate fall damage and distribute that information to clients
func calculateFallDamageServer(fallHeight, fallDamageHeight, fallDamageRate):
	var resultingDamage = (fallHeight - fallDamageHeight) * fallDamageRate
	if resultingDamage < 0:
		print("Error, damage is negative when they should be taking damage")
	elif !fallDamageImmunity:
		takeDamage(resultingDamage)
		rpc("takeDamageRPC", resultingDamage)

# Server receives call to locally execute damage and also replicate damage to clients
func serverBroadcastDamageRPC(damage):
	takeDamage(damage)
	rpc("takeDamageRPC", damage)

# I abstracted takeDamage as a local call instead of just making it a remote function in case I want to make local
# calls down the road and not quite sure if I need to yet.
remote func takeDamageRPC(damage):
	takeDamage(damage)

#################################UI FUNCTIONS

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
