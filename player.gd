extends Node2D

### Root Player component. Most functions, movement, controls, etc are handled in playerPhysicsBody, but this node controls camera when not focused on player and set values for children

var control   = false
var player_id = 0
var root      = false
var console   = false

var camera

var teleportCooldownTimer = Timer.new()
var maxTeleports = 1
var teleportCount = 0
var teleportCooldown = 30
var currentActivePawn
var teleporting = false
var teleport_node = preload("res://TeleportScene.tscn")
var teleport_instance
# Teleport penalty damage does at LEAST 20% of original health, but if current health is larger it will take that
# Mincheck1 checks if 10% of TOTAL health is the larger value
var teleport_penalty_damage_mincheck1 = 0.1
# Mincheck2 checks if 25% of CURRENT health is the larger value
var teleport_penalty_damage_mincheck2 = 0.25

var test = false

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
			
			rpc_id(1, "initiateTeleportServer", player_id)
			
		else:
			# remove UI for other players
			$PlayerCamera.get_node("GUI").queue_free()

func teleport():
	rpc_id(1, "initiateTeleportServer", player_id)

func requestTeleportToServer(pos):
	rpc_id(1, "serverTeleportPlayer", pos)
	rpc_id(1, "concludeTeleportServer", player_id)

remote func serverTeleportPlayer(pos):
	if get_tree().is_network_server():
		rpc("teleportPlayerRPC", pos)
		teleportPlayer(pos)

remote func teleportPlayerRPC(pos):
	teleportPlayer(pos)

func teleportPlayer(pos):
	$playerPhysicsBody.position = pos

remote func initiateTeleportServer(id):
	if get_tree().is_network_server():
		rpc("setInitiateTeleportVariablesRPC")
		setInitiateTeleportVariables()
		
		rpc_id(id, "approveInitiateTeleportRequestRPC")

remote func setInitiateTeleportVariablesRPC():
	setInitiateTeleportVariables()

func setInitiateTeleportVariables():
	# RPC TO ALL the player sprite being invisible and invincible
	$playerPhysicsBody.immortal = true
	$playerPhysicsBody.get_node("Sprite").visible = false
	# Disable Collisions
	$playerPhysicsBody.get_node("playrPhysicsShape").disabled = true
	$playerPhysicsBody.get_node("CollisionShape2D").disabled = true
	$playerPhysicsBody.get_node("DamageCollisionArea").get_node("DamageCollision").disabled = true

remote func approveInitiateTeleportRequestRPC():
	# RPC to JUST THE PLAYER the initiate teleport and the test var
	initiateTeleport()
	test = true

remote func concludeTeleportServer(id):
	if get_tree().is_network_server():
		rpc("setConcludeTeleportVariablesRPC")
		setConcludeTeleportVariables()
		
		rpc_id(id, "approveConcludeTeleportRequestRPC")

remote func setConcludeTeleportVariablesRPC():
	setConcludeTeleportVariables()

func setConcludeTeleportVariables():
	# RPC the player sprite being visible and able to take damage again
	$playerPhysicsBody.immortal = false
	$playerPhysicsBody.get_node("Sprite").visible = true
	# Re-Enable collisions
	$playerPhysicsBody.get_node("playrPhysicsShape").disabled = false
	$playerPhysicsBody.get_node("CollisionShape2D").disabled = false
	$playerPhysicsBody.get_node("DamageCollisionArea").get_node("DamageCollision").disabled = false

remote func approveConcludeTeleportRequestRPC():
	# RPC to JUST THE PLAYER the conclude teleport and the test var
	concludeTeleport()
	test = false

func initiateTeleport():
	freezePlayer()
	
	# Pause existing teleport cooldown if active
	if teleportCooldownTimer.get_time_left() > 0:
		teleportCooldownTimer.set_paused(true)
	
	# Set teleporting
	teleporting = true
	
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

func concludeTeleport():
	resetPlayer()
	teleporting = false

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
	camera.get_node("GUI").visible = false

func resetPlayer():
	$playerPhysicsBody.allowActions = true
	$playerPhysicsBody.allowMovement = true
	# Reset physics
	$playerPhysicsBody.jumping = false
	$playerPhysicsBody.jump_direction = Vector2.ZERO
	$playerPhysicsBody.peakHeight = $playerPhysicsBody.position.y
	$playerPhysicsBody._velocity = Vector2.ZERO
	# Enable HUD
	camera.get_node("GUI").visible = true

func teleportCooldownReset():
	if teleportCount < maxTeleports:
		teleportCount += 1

func useteleportCooldown():
	teleportCount -= 1
	teleportCooldownTimer.start()
