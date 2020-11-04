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

var accumulatedTeleportDamage = 0

var teleportSelectPenaltyTimer = Timer.new()
var teleportSelectPenaltyTime = 5
var teleportSelectPenaltyHealthTaken = 0.25

var teleportingPawn

var initialTeleport = true

var serverCompletedResponse = false

func _ready():
	initializePenaltyTimer()
	if (!get_tree().is_network_server() or (get_tree().is_network_server() and get_parent().server_controlled)) and get_parent().get_parent().control:
		initialize()

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

	if get_tree().is_network_server():
		if get_parent().server_controlled:
			setTeleportingPawnAsServer("MainPawn")
	else:
		setTeleportingPawnToServer("MainPawn")

func setTeleportingPawnToServer(pawnName):
	rpc_id(1, "setTeleportingPawnServer", pawnName)

func setTeleportingPawnAsServer(pawnName):
	setTeleportingPawnServerCall(pawnName)

remote func setTeleportingPawnServer(pawnName):
	setTeleportingPawnServerCall(pawnName)

func setTeleportingPawnServerCall(pawnName):
	rpc("setTeleportingPawnRPC", pawnName)
	setTeleportingPawn(pawnName)

remote func setTeleportingPawnRPC(pawnName):
	get_parent().get_node(pawnName).disableCollision()
	setTeleportingPawn(pawnName)

func setTeleportingPawn(pawnName):
	teleportingPawn = get_parent().get_node(pawnName)
	if get_parent().control:
		teleport()

# Calls teleporting from other nodes
func teleport():
	# Set teleporting
	teleportCheckTimer.start()
	
	if get_tree().is_network_server():
		if get_parent().server_controlled:
			initiateTeleportAsServer()
	else:
		rpc_id(1, "initiateTeleportServer", get_parent().player_id)

func initiateTeleportAsServer():
	initiateTeleportServerCall()
	call_deferred("initiateTeleport")
		
# Server knows to freeze and hide player for ALL clients
remote func initiateTeleportServer(id):
	initiateTeleportServerCall()
	rpc_id(id, "approveInitiateTeleportRequestRPC")

func initiateTeleportServerCall():
	if get_tree().is_network_server():
		rpc("setInitiateTeleportVariablesRPC")
		setInitiateTeleportVariables()

# Freezes and hides player for clients
remote func setInitiateTeleportVariablesRPC():
	setInitiateTeleportVariables()

# Freezes and hides player, called by server and clients
func setInitiateTeleportVariables():
	if initialTeleport:
		add_to_group("TeleportManagers")
	accumulatedTeleportDamage = 0
	if teleportingPawn.has_node("HealthManager"):
		teleportingPawn.get_node("HealthManager").hideMiniHPBar()
	if teleportingPawn.has_node("StateManager"):
		teleportingPawn.get_node("StateManager").freeze()
		teleportingPawn.get_node("StateManager").hide()
	if get_parent().has_node("PlayerCamera"):
		get_parent().get_node("PlayerCamera").hideCamera()
	teleporting = true
	# RPC TO ALL the player sprite being invisible and invincible

# Server now sends the client that called to teleport the instructions to choose new location
remote func approveInitiateTeleportRequestRPC():
	# RPC to JUST THE PLAYER the initiate teleport and the test var
	initiateTeleport()

# Instructions for freezing player and setting variables/views to choose teleport location
func initiateTeleport():
	# Pause existing teleport cooldown if active
	if teleportCooldownTimer.get_time_left() > 0:
		teleportCooldownTimer.set_paused(true)
	
	if get_parent().selectMinion:
		get_parent().removeMinionSelectLocation(true)
	
	# Change to teleporting mode
	teleport_instance = teleport_node.instance()
	# Get map center location:
	var map_center_location = Vector2((get_node("/root/").get_node("environment").get_node("TestMap").maxLength)/2, (get_node("/root/").get_node("environment").get_node("TestMap").maxHeight)/2)
	if get_parent().has_node("PlayerCamera"):
		get_parent().get_node("PlayerCamera").switchFromPlayerCamera()
		
	teleport_instance.entitySize = teleportingPawn.get_node("EntityCollision/EntityCollisionShape").shape.extents
	# Instantiate the teleport node
	get_parent().add_child(teleport_instance)
	# Set teleport's camera and location
	teleport_instance.setCamera()
	teleport_instance.setCameraLocation(map_center_location)
	
	serverCompletedResponse = true
	teleport_check = true
	
	get_parent().teleport_gui = get_node("../TeleportScene/TeleportCamera/CanvasLayer/GUI")
	get_parent().switch_gui_to_teleport()
	
	startTeleportSelectPenaltyTimer()



# Calls teleport to the server with location so server can return calls to client
func requestTeleportToServer(pos):
	teleportSelectPenaltyTimer.stop()
	rpc_id(1, "serverTeleportPlayer", pos)
	rpc_id(1, "concludeTeleportServer", get_parent().player_id)

func requestTeleportAsServer(pos):
	serverTeleportPlayerCall(pos)
	concludeTeleportServerCall(get_parent().player_id)

# Server tells ALL clients via RPC of the new location, then calls locally
remote func serverTeleportPlayer(pos):
	serverTeleportPlayerCall(pos)

func serverTeleportPlayerCall(pos):
	if get_tree().is_network_server():
		rpc("teleportPlayerRPC", pos)
		teleportPlayer(pos)
		teleportSelectPenaltyTimer.stop()

# Clients get new location from server and call new location
remote func teleportPlayerRPC(pos):
	teleportPlayer(pos)

# Function that changes position of player to new position
func teleportPlayer(pos):
	teleportingPawn.position = pos

# After teleport is complete, we proceed with having the server unhide the player and unfreeze, and etc
remote func concludeTeleportServer(id):
	concludeTeleportServerCall(id)

func concludeTeleportServerCall(id):
	if get_tree().is_network_server():

		if initialTeleport:
			if get_parent().server_controlled:
				showPawn()
			else:
				rpc_id(id, "showPawnRPC")
		else:
			rpc("setConcludeTeleportVariablesRPC")
			setConcludeTeleportVariables()

		if get_parent().server_controlled:
			concludeTeleport()
		else:
			rpc_id(id, "approveConcludeTeleportRequestRPC")

remote func showPawnRPC():
	showPawn()

func showPawn():
	if teleportingPawn.has_node("StateManager"):
		teleportingPawn.get_node("StateManager").showSpriteOnly()

# All clients receive new information from server on unhiding and allowing resuming of actions
remote func setConcludeTeleportVariablesRPC():
	setConcludeTeleportVariables()

# Unhide and allow resuming of actions
func setConcludeTeleportVariables():
	# RPC the player sprite being visible and able to take damage again
	if teleportingPawn.has_node("HealthManager"):
		teleportingPawn.get_node("HealthManager").showMiniHPBar()
	if teleportingPawn.has_node("StateManager"):
		teleportingPawn.get_node("StateManager").reset()
		teleportingPawn.get_node("StateManager").show()
	if get_parent().has_node("PlayerCamera"):
		get_parent().get_node("PlayerCamera").showCamera()

# Server now sends the client that called to teleport the instructions to set cooldown, unfreeze character, etc
remote func approveConcludeTeleportRequestRPC():
	# RPC to JUST THE PLAYER the conclude teleport and the test var
	concludeTeleport()

# Instructions after teleporting to change variables/views back to original character and set cooldown/damage
func concludeTeleport():

	# Exit teleporting mode
	# Clear Camera
	teleport_instance.clearCamera()
	
	if get_parent().has_node("PlayerCamera"):
		get_parent().get_node("PlayerCamera").switchToPlayerCamera()
	
	# Remove old node
	teleport_instance.queue_free()
	
	if get_parent().has_node("PlayerCamera"):
		get_parent().get_node("PlayerCamera").changeTarget(teleportingPawn)
	
	get_parent().switchToPawn(teleportingPawn.name)
	
	# If cooldown is active (>0), resume the cooldown and deal cooldown penalty
	if teleportCooldownTimer.get_time_left() > 0:
		teleportCooldownTimer.set_paused(false)
		if teleportingPawn.has_node("HealthManager"):
			var pawnHealthManager = teleportingPawn.get_node("HealthManager")
			pawnHealthManager.serverBroadcastDamageRPC(max(pawnHealthManager.maxHealth * teleport_penalty_damage_mincheck1, pawnHealthManager.health * teleport_penalty_damage_mincheck2), false)
	else:
		# If cooldown is not active (== 0), set cooldown
		useteleportCooldown()

	get_parent().switch_gui_to_player()

	if get_tree().is_network_server():
		if get_parent().server_controlled:
			broadcastTeleportConclusion()
			rpc("broadcastTeleportConclusionRPC")
	else:
		rpc_id(1, "broadcastTeleportConclusionServer")
	
remote func broadcastTeleportConclusionServer():
	broadcastTeleportConclusion()
	rpc("broadcastTeleportConclusionRPC")
	
remote func broadcastTeleportConclusionRPC():
	broadcastTeleportConclusion()
	
func broadcastTeleportConclusion():
	if !initialTeleport:
		teleportingPawn = null
		teleporting = false
	else:
		initialTeleport = false


func concludeTeleportAsServer():
	rpc("setConcludeTeleportVariablesRPC")
	setConcludeTeleportVariables()
	rpc("concludeTeleportInitialRPC")
	concludeTeleportInitial()

remote func concludeTeleportInitialRPC():
	concludeTeleportInitial()
	
func concludeTeleportInitial():
	teleportingPawn = null
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

func initializePenaltyTimer():
	# Instantiate RPC check timer
	teleportSelectPenaltyTimer.set_wait_time(teleportSelectPenaltyTime)
	teleportSelectPenaltyTimer.set_one_shot(false)
	teleportSelectPenaltyTimer.connect("timeout", self, "teleportSelectPenalty")
	add_child(teleportSelectPenaltyTimer)

func startTeleportSelectPenaltyTimer():
	teleportSelectPenaltyTimer.start()
	if !get_tree().is_network_server():
		rpc_id(1, "startTeleportSelectPenaltyTimerServer")

remote func startTeleportSelectPenaltyTimerServer():
	if get_tree().is_network_server():
		teleportSelectPenaltyTimer.start()

func teleportSelectPenalty():
	if get_tree().is_network_server():
		if teleportingPawn.has_node("HealthManager"):
			var pawnHealthManager = teleportingPawn.get_node("HealthManager")
			var penaltyDamage = pawnHealthManager.maxHealth * teleportSelectPenaltyHealthTaken
			pawnHealthManager.serverBroadcastDamageRPC(penaltyDamage, true)
			accumulatedTeleportDamage += penaltyDamage
			rpc("sendAccumulatedTeleportDamage", accumulatedTeleportDamage)

remote func sendAccumulatedTeleportDamage(accumulatedTeleportDamageRPC):
	accumulatedTeleportDamage = accumulatedTeleportDamageRPC
