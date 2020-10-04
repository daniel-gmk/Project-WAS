extends Node2D

### Health
var minHealth = 0
export var maxHealth = 10000
export var MainHealthBar = true
var health
var immortal = false
export var fallDamageImmunity = false

var player_node

### HUD
# Track the HUD component path
var GUI_node
# Use the path to grab the Main player's Health bar (Child Component of HUD) as a var
var health_bar_root
# Use the path to grab the Main player's Health bar value text (Child Component of Health bar) as a var
var health_bar_text

func _ready():
	player_node = get_parent().get_parent()
	# Set health
	health = maxHealth
	if !get_tree().is_network_server() and player_node.control and MainHealthBar and get_parent().MainPawn:
		GUI_node = player_node.get_node("PlayerCamera/CanvasLayer/GUI")
		health_bar_root = GUI_node.find_node("MainHealthBar")
		health_bar_text = health_bar_root.find_node("HealthValueText")
		initiate_ui()
	# Not entirely sure if this does anything but it sets collision monitoring on for the character to detect aoe damage
	$DamageCollisionArea.monitorable = true

func enableDamageCollision():
	get_node("DamageCollisionArea/DamageCollision").disabled = false

func disableDamageCollision():
	get_node("DamageCollisionArea/DamageCollision").disabled = true

# Handles when damage is taken
func takeDamage(damage):
	if damage < 0:
		print("Error: Negative damage reported")
	if !immortal:
		health -= damage
		# Update health bar HUD
		if get_tree().get_network_unique_id() == player_node.player_id and get_parent().MainPawn:
			health_bar_root.value = health
			health_bar_text.text = String(round(health))
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
func initiate_ui():
	# Set Health Bar
	health_bar_root.max_value = maxHealth
	health_bar_root.min_value = minHealth
	health_bar_root.value = health
	health_bar_text.text = String(health)
