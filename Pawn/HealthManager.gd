extends Node

### Health
var minHealth = 0
export var maxHealth = 10000
export var MainHealthBar = true
var health
var immortal = false

### HUD
# Track the HUD component path
export var GUI_node_path : NodePath
# Use the path to grab the Main player's Health bar (Child Component of HUD) as a var
onready var health_bar_root = get_node(GUI_node_path).find_node("MainHealthBar")
# Use the path to grab the Main player's Health bar value text (Child Component of Health bar) as a var
onready var health_bar_text = health_bar_root.find_node("HealthValueText")

func _ready():
	# Set health
	health = maxHealth
	# Not entirely sure if this does anything but it sets collision monitoring on for the character to detect aoe damage
	if get_parent().has_node("DamageCollisionArea"):
		# Reset attack charge
		get_parent().get_node("DamageCollisionArea").monitorable = true

func enableDamageCollision():
	if get_parent().has_node("DamageCollisionArea"):
		get_parent().get_node("DamageCollisionArea/DamageCollision").disabled = false

func disableDamageCollision():
	if get_parent().has_node("DamageCollisionArea"):
		get_parent().get_node("DamageCollisionArea/DamageCollision").disabled = true

# Handles when damage is taken
func takeDamage(damage):
	if damage < 0:
		print("Error: Negative damage reported")
	if !immortal:
		health -= damage
		# Update health bar HUD
		if get_tree().get_network_unique_id() == get_parent().get_parent().player_id:
			health_bar_root.value = health
			health_bar_text.text = String(round(health))
		# Dead if health falls below min value
		if health <= minHealth:
			death()

# Handles when dead, not implemented yet since gamemode should be created first
func death():
	print("I died")

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
