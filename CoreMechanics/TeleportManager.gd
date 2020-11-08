extends Node

### Main Variables

### Main Teleporting Variables
# Keeps track of whether player is teleporting
var teleporting = false
# Tracks whether the pawn is teleporting at the beginning of the match
var initialTeleport = true
# Tracks the pawn currently teleporting
var teleportingPawn
# Tracks the node used for teleporting, which the player assumes when teleporting
var teleport_node = preload("res://CoreMechanics/TeleportScene.tscn")
# Tracks the instantiation of above teleport node
var teleport_instance

### Teleport RPC Handshake Variables
# Tracks whether the client correctly received a teleport signal from the server upon initiation
var teleport_check = false
# This timer makes sure teleporting is not skipped by the server
var teleportCheckTimer = Timer.new()
# Tracks whether the client correctly received a teleport signal from the server upon location selection
var serverCompletedResponse = false

### Teleport Cooldown Variables
### Teleport Cooldown is when there are certain amount of teleports you can have before you start taking damage before it's recovered
# The actual Timer node used for Teleport Cooldowns
var teleportCooldownTimer = Timer.new()
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
# Tracks how much teleport penalty damage was applied during teleport location selection
var accumulatedTeleportDamage = 0

### Teleport Selection Penalty Variables
### Teleport Selection Penalty is when the player is not choosing a teleport location in time, in which a damage penalty is dealt
# Timer used to deal damage when timer ends before player chose a location to teleport
var teleportSelectPenaltyTimer = Timer.new()
# Time before damage is dealt before player chooses a location to teleport
var teleportSelectPenaltyTime = 5
# Percent of overall HP dealth each iteration of time a player does not choose a location to teleport
var teleportSelectPenaltyHealthTaken = 0.25

# Called when node is initialized
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

	# Call teleport on node
	if get_tree().is_network_server():
		if get_parent().server_controlled:
			setTeleportingPawnServerCall("MainPawn")
	else:
		setTeleportingPawnToServer("MainPawn")

# Wrapper RPC as client to call server to set teleport pawn
func setTeleportingPawnToServer(pawnName):
	rpc_id(1, "setTeleportingPawnServer", pawnName)

# Wrapper RPC to call as server from client to set teleport pawn
remote func setTeleportingPawnServer(pawnName):
	setTeleportingPawnServerCall(pawnName)

# Wrapper RPC to call as server locally and call clients to set teleport pawn
func setTeleportingPawnServerCall(pawnName):
	rpc("setTeleportingPawnRPC", pawnName)
	setTeleportingPawn(pawnName)

# Wrapper RPC to call as client locally from server to set teleport pawn
remote func setTeleportingPawnRPC(pawnName):
	get_parent().get_node(pawnName).disableCollision()
	setTeleportingPawn(pawnName)

# Set teleport pawn and call teleport
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
		rpc_id(1, "initiateTeleportServer", int(get_parent().clientName))

# Wrapper RPC to have server call locally for P2P server to broadcast variables and initiate teleport
func initiateTeleportAsServer():
	initiateTeleportServerCall()
	call_deferred("initiateTeleport")

# Wrapper RPC to have server sent from client to broadcast variables and return to calling client (as handshake) to initiate teleport
remote func initiateTeleportServer(id):
	initiateTeleportServerCall()
	rpc_id(id, "approveInitiateTeleportRequestRPC")

# Wrapper RPC to have server broadcast variables to all clients and initiate teleport locally
func initiateTeleportServerCall():
	if get_tree().is_network_server():
		rpc("setInitiateTeleportVariablesRPC")
		setInitiateTeleportVariables()

# Wrapper RPC from server to client to set teleport variables locally
remote func setInitiateTeleportVariablesRPC():
	setInitiateTeleportVariables()

# Freezes and hides player
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

# Server now sends to client that called to teleport to choose new location
remote func approveInitiateTeleportRequestRPC():
	# RPC to JUST THE PLAYER the initiate teleport and the test var
	initiateTeleport()

# Attaches teleport selection module and moves camera to the teleport's view
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
	
	# Set variables
	serverCompletedResponse = true
	teleport_check = true	
	startTeleportSelectPenaltyTimer()
	
	# Switch to teleport GUI
	get_parent().teleport_gui = get_node("../TeleportScene/TeleportCamera/CanvasLayer/GUI")
	get_parent().switch_gui_to_teleport()

# Wrapper RPC for client calls server to teleport player and handshake back to conclude teleport back to client
func requestTeleportToServer(pos):
	teleportSelectPenaltyTimer.stop()
	rpc_id(1, "serverTeleportPlayer", pos)
	rpc_id(1, "concludeTeleportServer", int(get_parent().clientName))

# Wrapper RPC for server to call P2P locally to teleport player and conclude teleport
func requestTeleportAsServer(pos):
	serverTeleportPlayerCall(pos)
	concludeTeleportServerCall(int(get_parent().clientName))

# Wrapper RPC for client from server to teleport player
remote func serverTeleportPlayer(pos):
	serverTeleportPlayerCall(pos)

# Wrapper RPC for server to broadcast teleport to clients and teleport locally
func serverTeleportPlayerCall(pos):
	if get_tree().is_network_server():
		rpc("teleportPlayerRPC", pos)
		teleportPlayer(pos)
		teleportSelectPenaltyTimer.stop()

# Wrapper RPC for clients to get new location from server and call new location
remote func teleportPlayerRPC(pos):
	teleportPlayer(pos)

# Sets position for player based on teleport request
func teleportPlayer(pos):
	teleportingPawn.position = pos

# Wrapper RPC for server called by client to conclude teleport
remote func concludeTeleportServer(id):
	concludeTeleportServerCall(id)

# Called by server to broadcast conclude teleport and set variables for teleport end
func concludeTeleportServerCall(id):
	if get_tree().is_network_server():

		# Show Pawn only for initial teleport, since conclusion will be initiated once all player teleports are complete
		if initialTeleport:
			if get_parent().server_controlled:
				showPawn()
			else:
				rpc_id(id, "showPawnRPC")
		else:
			# Set conclusion variables
			rpc("setConcludeTeleportVariablesRPC")
			setConcludeTeleportVariables()

		# Conclude teleport
		if get_parent().server_controlled:
			concludeTeleport()
		else:
			rpc_id(id, "approveConcludeTeleportRequestRPC")

# Wrapper RPC for client called by server to show pawn
remote func showPawnRPC():
	showPawn()

# Shows the pawn sprite
func showPawn():
	if teleportingPawn.has_node("StateManager"):
		teleportingPawn.get_node("StateManager").showSpriteOnly()

# Wrapper RPC from server broadcasting to clients to reset and show pawn after teleport
remote func setConcludeTeleportVariablesRPC():
	setConcludeTeleportVariables()

# Reset and show pawn after teleport
func setConcludeTeleportVariables():
	if teleportingPawn.has_node("HealthManager"):
		teleportingPawn.get_node("HealthManager").showMiniHPBar()
	if teleportingPawn.has_node("StateManager"):
		teleportingPawn.get_node("StateManager").reset()
		teleportingPawn.get_node("StateManager").show()
	if get_parent().has_node("PlayerCamera"):
		get_parent().get_node("PlayerCamera").showCamera()

# Wrapper RPC from server broadcasting to calling client (as handshake) to conclude teleport
remote func approveConcludeTeleportRequestRPC():
	concludeTeleport()

# Instructions after teleporting to change variables/views back to original character and set cooldown/damage
func concludeTeleport():

	# Exit teleporting mode
	# Clear and switch Camera
	teleport_instance.clearCamera()
	if get_parent().has_node("PlayerCamera"):
		get_parent().get_node("PlayerCamera").switchToPlayerCamera()
		get_parent().get_node("PlayerCamera").changeTarget(teleportingPawn)

	# Remove old node
	teleport_instance.queue_free()

	# Switch pawn to original teleporting pawn
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

	# Switch GUI back
	get_parent().switch_gui_to_player()

	# Confirm conclusion variables as handshake to self, server, and all other clients
	if get_tree().is_network_server():
		if get_parent().server_controlled:
			broadcastTeleportConclusion()
			rpc("broadcastTeleportConclusionRPC")
	else:
		rpc_id(1, "broadcastTeleportConclusionServer")

# Wrapper RPC from client to server to locally call and broadcast confirmation of conclusion variable to other clients
remote func broadcastTeleportConclusionServer():
	broadcastTeleportConclusion()
	rpc("broadcastTeleportConclusionRPC")

# Wrapper RPC from server to client to locally confirm conclusion variable
remote func broadcastTeleportConclusionRPC():
	broadcastTeleportConclusion()

# Set teleporting and confirmation of variables as concluded
func broadcastTeleportConclusion():
	if !initialTeleport:
		teleportingPawn = null
		teleporting = false
	else:
		initialTeleport = false

### Conclusion of teleporting by initial teleport
# Wrapper RPC for server to set conclusion variables and conclude initial teleport
func concludeTeleportAsServer():
	rpc("setConcludeTeleportVariablesRPC")
	setConcludeTeleportVariables()
	rpc("concludeTeleportInitialRPC")
	concludeTeleportInitial()

# Wrapper RPC from server to client to conclude initial teleport
remote func concludeTeleportInitialRPC():
	concludeTeleportInitial()

# Set teleport as false, conclude variables
func concludeTeleportInitial():
	teleportingPawn = null
	teleporting = false

#########################Teleport RPC Handshake

# Function for making sure teleport was called
func checkTeleportReachedRPC():
	if teleport_check:
		teleport_check = false
		teleportCheckTimer.stop()
	else:
		rpc_id(1, "initiateTeleportServer", get_parent().player_id)

#########################Teleport Cooldown

# Function handling when teleport cooldown is over and teleport is replenished
func teleportCooldownReset():
	if teleportCount < maxTeleports:
		teleportCount += 1

# Function for consuming a teleport value and starting the cooldown for replenishing
func useteleportCooldown():
	teleportCount -= 1
	teleportCooldownTimer.start()

#########################Teleport Penalty

# Initialize teleport penalty timer at beginning of game
func initializePenaltyTimer():
	# Instantiate RPC check timer
	teleportSelectPenaltyTimer.set_wait_time(teleportSelectPenaltyTime)
	teleportSelectPenaltyTimer.set_one_shot(false)
	teleportSelectPenaltyTimer.connect("timeout", self, "teleportSelectPenalty")
	add_child(teleportSelectPenaltyTimer)

# Wrapper RPC as client to call server to start teleport penalty timer
func startTeleportSelectPenaltyTimer():
	teleportSelectPenaltyTimer.start()
	if !get_tree().is_network_server():
		rpc_id(1, "startTeleportSelectPenaltyTimerServer")

# Wrapper RPC as server to start teleport penalty timer
remote func startTeleportSelectPenaltyTimerServer():
	if get_tree().is_network_server():
		teleportSelectPenaltyTimer.start()

# Called every teleport penalty to deal damage
func teleportSelectPenalty():
	if get_tree().is_network_server():
		if teleportingPawn.has_node("HealthManager"):
			var pawnHealthManager = teleportingPawn.get_node("HealthManager")
			var penaltyDamage = pawnHealthManager.maxHealth * teleportSelectPenaltyHealthTaken
			pawnHealthManager.serverBroadcastDamageRPC(penaltyDamage, true)
			accumulatedTeleportDamage += penaltyDamage
			rpc("sendAccumulatedTeleportDamage", accumulatedTeleportDamage)

#########################Teleport GUI

# Update GUI to show total penalty damage
remote func sendAccumulatedTeleportDamage(accumulatedTeleportDamageRPC):
	accumulatedTeleportDamage = accumulatedTeleportDamageRPC
