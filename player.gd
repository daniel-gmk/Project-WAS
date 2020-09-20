extends Node2D

### Root Player component. Most functions, movement, controls, etc are handled in playerPhysicsBody, but this node controls camera when not focused on player and set values for children

var control   = false
var player_id = 0
var root      = false
var console   = false
# Track current active pawn, for example teleport node, playerPhysicsBody node, or down the road minions
var currentActivePawn
# Tracks camera node
var camera

### Variables for teleporting
# Keeps track of whether player is teleporting
var teleporting = false
var teleport_check = false
# Tracks the node used for teleporting, which the player assumes when teleporting
var teleport_node = preload("res://TeleportScene.tscn")
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

func _ready():
	# Don't show any GUI elements to the server
	if get_tree().is_network_server():
		$PlayerCamera.queue_free()
		if control:
			$playerPhysicsBody.control = control
			$playerPhysicsBody.player_id = player_id
	else:
		# Pass variables to children only if local player
		if control:
			currentActivePawn = $playerPhysicsBody
			$playerPhysicsBody.control = control
			$playerPhysicsBody.player_id = player_id
			$playerPhysicsBody.initiate_ui()
	
			# Set camera focus to player
			$PlayerCamera.control = control
			camera = $PlayerCamera
			camera.root = self
			camera.playerOwner = $playerPhysicsBody
			camera.make_current()
			camera.changeToPlayerOwner()
			
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
			
			rpc_id(1, "initiateTeleportServer", player_id)
			
		else:
			# remove UI for other players
			$PlayerCamera.get_node("GUI").queue_free()

# Calls teleporting from other nodes
func teleport():
	# Set teleporting
	teleporting = true
	teleportCheckTimer.start()
	rpc_id(1, "initiateTeleportServer", player_id)

# Calls teleport to the server with location so server can return calls to client
func requestTeleportToServer(pos):
	rpc_id(1, "serverTeleportPlayer", pos)
	rpc_id(1, "concludeTeleportServer", player_id)

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
	$playerPhysicsBody.position = pos

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
	freezePlayer()
	# RPC TO ALL the player sprite being invisible and invincible
	$playerPhysicsBody.immortal = true
	$playerPhysicsBody.get_node("Sprite").visible = false
	# Disable Collisions
	$playerPhysicsBody.get_node("CollisionShape2D").disabled = true
	$playerPhysicsBody.get_node("PlayerCollision").get_node("PlayerCollisionShape").disabled = true
	$playerPhysicsBody.get_node("DamageCollisionArea").get_node("DamageCollision").disabled = true

# Server now sends the client that called to teleport the instructions to choose new location
remote func approveInitiateTeleportRequestRPC():
	# RPC to JUST THE PLAYER the initiate teleport and the test var
	initiateTeleport()

# After teleport is complete, we proceed with having the server unhide the player and unfreeze, and etc
remote func concludeTeleportServer(id):
	if get_tree().is_network_server():
		rpc("setConcludeTeleportVariablesRPC")
		setConcludeTeleportVariables()
		
		rpc_id(id, "approveConcludeTeleportRequestRPC")

# All clients receive new information from server on unhiding and allowing resuming of actions
remote func setConcludeTeleportVariablesRPC():
	setConcludeTeleportVariables()

# Unhide and allow resuming of actions
func setConcludeTeleportVariables():
	resetPlayer()
	# RPC the player sprite being visible and able to take damage again
	$playerPhysicsBody.immortal = false
	$playerPhysicsBody.get_node("Sprite").visible = true
	# Re-Enable collisions
	$playerPhysicsBody.get_node("CollisionShape2D").disabled = false
	$playerPhysicsBody.get_node("PlayerCollision").get_node("PlayerCollisionShape").disabled = false
	$playerPhysicsBody.get_node("DamageCollisionArea").get_node("DamageCollision").disabled = false

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
	# Reset current camera
	camera.changeToPlayerOwner()
	camera.lastPlayerOwnerPosition = false
	camera.position = Vector2.ZERO
	# Remove current camera
	camera.clear_current()
	# Set mouse location and view
	get_viewport().warp_mouse(get_viewport_rect().size / 2)
	# Instantiate the teleport node
	add_child(teleport_instance)
	# Set teleport's camera and location
	teleport_instance.setCamera()
	teleport_instance.setCameraLocation(map_center_location)
	# Set current pawn
	currentActivePawn = teleport_instance

# Instructions after teleporting to change variables/views back to original character and set cooldown/damage
func concludeTeleport():

	# Exit teleporting mode
	# Clear Camera
	teleport_instance.clearCamera()
	# Set mouse location and view
	get_viewport().warp_mouse(get_viewport_rect().size / 2)
	# Set new pawn camera
	camera.make_current()
	# Reset camera position
	camera.changeToPlayerOwner()
	camera.lastPlayerOwnerPosition = false
	camera.position = Vector2.ZERO
	
	# Set current pawn
	currentActivePawn = $playerPhysicsBody
	# Remove old node
	teleport_instance.queue_free()
	
	# If cooldown is active (>0), resume the cooldown and deal cooldown penalty
	if teleportCooldownTimer.get_time_left() > 0:
		teleportCooldownTimer.set_paused(false)
		$playerPhysicsBody.serverBroadcastDamageRPC(max($playerPhysicsBody.maxHealth * teleport_penalty_damage_mincheck1, $playerPhysicsBody.health * teleport_penalty_damage_mincheck2))
	else:
		# If cooldown is not active (== 0), set cooldown
		useteleportCooldown()
	
	teleporting = false

# Instructions for freezing player character
func freezePlayer():
	$playerPhysicsBody.allowActions = false
	$playerPhysicsBody.allowMovement = false
	# Reset attack charge
	$playerPhysicsBody._attack_power = 0
	$playerPhysicsBody._attack_clicked = false
	# Hide the reticule now that firing is done
	$playerPhysicsBody.chargeProgress.visible = false
	$playerPhysicsBody.chargeProgress.value = 0
	# Disable HUD
	if control:
		camera.get_node("GUI").visible = false

# Instructions for unfreezing AND resetting player character values (jumping, attacking, etc)
func resetPlayer():
	$playerPhysicsBody.allowActions = true
	$playerPhysicsBody.allowMovement = true
	# Reset physics
	$playerPhysicsBody.jumping = false
	$playerPhysicsBody.peakHeight = $playerPhysicsBody.position.y
	$playerPhysicsBody._velocity = Vector2.ZERO
	# Enable HUD
	if control:
		camera.get_node("GUI").visible = true

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
		rpc_id(1, "initiateTeleportServer", player_id)
