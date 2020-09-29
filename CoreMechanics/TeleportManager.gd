extends Node

### Variables for teleporting
# Keeps track of whether player is teleporting
var teleporting = false
var teleport_check = false
# Tracks the node used for teleporting, which the player assumes when teleporting
var teleport_node = preload("res://CoreMechanics/TeleportScene.tscn")
# Tracks the instantiation of above teleport node
var teleport_instance
# The actual Timer node used for Teleport Cooldowns
var teleportCooldownTimer = Timer.new()
# This timer makes sure teleporting is not skipped by the server
var teleportCheckTimer = Timer.new()
# Max number of teleports allowed for player
var maxTeleports = 1
# Current count of teleports
var teleportCount = 0
# Cooldown value for teleporting before dealing penalty damage
var teleportCooldown = 30
# Teleport penalty damage does at LEAST 20% of original health, but if current health is larger it will take that
# Mincheck1 checks if 10% of TOTAL health is the larger value
var teleport_penalty_damage_mincheck1 = 0.1
# Mincheck2 checks if 25% of CURRENT health is the larger value
var teleport_penalty_damage_mincheck2 = 0.25

var initialTeleport = true

func initialize():
	# Set Teleport Cooldown and timers
	teleportCount = maxTeleports
	
	teleportCooldownTimer.set_wait_time(teleportCooldown)
	# Make sure its not just a one time execution and loops infinitely
	teleportCooldownTimer.set_one_shot(true)
	# Perform inAction_loop function each execution
	teleportCooldownTimer.connect("timeout", self, "teleportCooldownReset")
	# Instantiate and start the timer
	add_child(teleportCooldownTimer)
	
	# Instantiate RPC check timer
	teleportCheckTimer.set_wait_time(3)
	teleportCheckTimer.set_one_shot(false)
	teleportCheckTimer.connect("timeout", self, "checkTeleportReachedRPC")
	add_child(teleportCheckTimer)
	
	get_parent().player_id
	get_parent().teleportingPawn
	
	rpc_id(1, "initiateTeleportServer", get_parent().player_id)
	
# Calls teleporting from other nodes
func teleport():
	# Set teleporting
	teleporting = true
	teleportCheckTimer.start()
	rpc_id(1, "initiateTeleportServer", get_parent().player_id)

# Calls teleport to the server with location so server can return calls to client
func requestTeleportToServer(pos):
	rpc_id(1, "serverTeleportPlayer", pos)
	rpc_id(1, "concludeTeleportServer", get_parent().player_id)

# Server tells ALL clients via RPC of the new location, then calls locally
remote func serverTeleportPlayer(pos):
	if get_tree().is_network_server():
		rpc("teleportPlayerRPC", pos)
		teleportPlayer(pos)

# Clients get new location from server and call new location
remote func teleportPlayerRPC(pos):
	teleportPlayer(pos)

# Function that changes position of player to new position
func teleportPlayer(pos):
	get_parent().teleportingPawn.position = pos

# Server knows to freeze and hide player for ALL clients
remote func initiateTeleportServer(id):
	if get_tree().is_network_server():
		rpc("setInitiateTeleportVariablesRPC")
		setInitiateTeleportVariables()
		
		rpc_id(id, "approveInitiateTeleportRequestRPC")

# Freezes and hides player for clients
remote func setInitiateTeleportVariablesRPC():
	setInitiateTeleportVariables()

# Freezes and hides player, called by server and clients
func setInitiateTeleportVariables():
	if initialTeleport:
		add_to_group("TeleportManagers")
	if get_parent().teleportingPawn.has_node("StateManager"):
		get_parent().teleportingPawn.get_node("StateManager").freeze()
		get_parent().teleportingPawn.get_node("StateManager").hide()
	get_parent().hideCamera()
	teleporting = true
	# RPC TO ALL the player sprite being invisible and invincible

# Server now sends the client that called to teleport the instructions to choose new location
remote func approveInitiateTeleportRequestRPC():
	# RPC to JUST THE PLAYER the initiate teleport and the test var
	initiateTeleport()

# After teleport is complete, we proceed with having the server unhide the player and unfreeze, and etc
remote func concludeTeleportServer(id):
	if get_tree().is_network_server():

		if initialTeleport:
			rpc_id(id, "showPawnRPC")
			showPawn()
		else:
			rpc("setConcludeTeleportVariablesRPC")
			setConcludeTeleportVariables()
		
		rpc_id(id, "approveConcludeTeleportRequestRPC")

		initialTeleport = false

func concludeTeleportAsServer():
	rpc("setConcludeTeleportVariablesRPC")
	setConcludeTeleportVariables()

# All clients receive new information from server on unhiding and allowing resuming of actions
remote func setConcludeTeleportVariablesRPC():
	setConcludeTeleportVariables()

# Unhide and allow resuming of actions
func setConcludeTeleportVariables():
	# RPC the player sprite being visible and able to take damage again
	if get_parent().teleportingPawn.has_node("StateManager"):
		get_parent().teleportingPawn.get_node("StateManager").reset()
		get_parent().teleportingPawn.get_node("StateManager").show()
	get_parent().showCamera()
	teleporting = false

remote func showPawnRPC():
	showPawn()

func showPawn():
	if get_parent().teleportingPawn.has_node("StateManager"):
		get_parent().teleportingPawn.get_node("StateManager").showSpriteOnly()

# Server now sends the client that called to teleport the instructions to set cooldown, unfreeze character, etc
remote func approveConcludeTeleportRequestRPC():
	# RPC to JUST THE PLAYER the conclude teleport and the test var
	concludeTeleport()

# Instructions for freezing player and setting variables/views to choose teleport location
func initiateTeleport():
	
	# Pause existing teleport cooldown if active
	if teleportCooldownTimer.get_time_left() > 0:
		teleportCooldownTimer.set_paused(true)
	
	teleport_check = true
	
	# Change to teleporting mode
	teleport_instance = teleport_node.instance()
	# Get map center location:
	var map_center_location = Vector2((get_node("/root/").get_node("environment").get_node("TestMap").maxLength)/2, (get_node("/root/").get_node("environment").get_node("TestMap").maxHeight)/2)
	get_parent().switchFromPlayerCamera()
	# Instantiate the teleport node
	get_parent().add_child(teleport_instance)
	# Set teleport's camera and location
	teleport_instance.setCamera()
	teleport_instance.setCameraLocation(map_center_location)
	# Set current pawn
	get_parent().currentActivePawn = teleport_instance

# Instructions after teleporting to change variables/views back to original character and set cooldown/damage
func concludeTeleport():

	# Exit teleporting mode
	# Clear Camera
	teleport_instance.clearCamera()
	
	get_parent().switchToPlayerCamera()
	
	# Set current pawn
	get_parent().currentActivePawn = get_parent().teleportingPawn
	# Remove old node
	teleport_instance.queue_free()
	
	# If cooldown is active (>0), resume the cooldown and deal cooldown penalty
	if teleportCooldownTimer.get_time_left() > 0:
		teleportCooldownTimer.set_paused(false)
		var pawnHealthManager = get_parent().currentActivePawn.get_node("HealthManager")
		pawnHealthManager.serverBroadcastDamageRPC(max(pawnHealthManager.maxHealth * teleport_penalty_damage_mincheck1, pawnHealthManager.health * teleport_penalty_damage_mincheck2))
	else:
		# If cooldown is not active (== 0), set cooldown
		useteleportCooldown()
	
	teleporting = false

# Function handling when teleport cooldown is over and teleport is replenished
func teleportCooldownReset():
	if teleportCount < maxTeleports:
		teleportCount += 1

# Function for consuming a teleport value and starting the cooldown for replenishing
func useteleportCooldown():
	teleportCount -= 1
	teleportCooldownTimer.start()

# Function for making sure teleport was called
func checkTeleportReachedRPC():
	if teleport_check:
		teleport_check = false
		teleportCheckTimer.stop()
	else:
		rpc_id(1, "initiateTeleportServer", get_parent().player_id)
