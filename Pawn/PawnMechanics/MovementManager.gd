extends KinematicBody2D

##### Main node for handling function, controls/input, values for UI, etc

### Main Variables
# Whether this is the player's main pawn or a minion
export var MainPawn = true
# Tracks the player's node that owns this pawn
var player_node
# Tracks whether the node is initialized
var initialized = false
# Tracks if the node is pending deletion
var terminatePending = false
# Timer for tracking time left before deletion
var terminateTimer = Timer.new()

### Physics
# Track if is allowed to move
export var allowMovement = false
# Vector tracking movement speed
export var _speed = 220
# Vector tracking current gravity
export var gravity = Vector2(0, 1800)
# Vector tracking movement/velocity
var _velocity : Vector2 = Vector2.ZERO
# Track if in the air or not
var airTime = false
# Track if forces are applied to the pawn (knockback)
var appliedForce = false
# Track if the pawn can perform movement in the air after knockback/force
var allowForceResistance = false

### Client side prediction / Server reconciliation vars
# Tracks overall movement of the node, passed from MovementInputManager
var movement = Vector2()
# Tracks last movement of the node passed from MovementInputManager
var old_movement = Vector2()
# Tracks server's version of node movement
master var remote_movement = Vector2()
# Tracks server's version of node transformation based on movement passed to client
puppet var remote_transform = Transform2D()
# Tracks server's version of velocity passed to client
puppet var remote_vel = Vector2()
# Server's last movement acknowledged passed to client
puppet var ack = 0 
# Tracks time passed from MovementInputManager
var time = 0

###Jump
# Tracking if Jumping
var jumping = false
# Tracking if Jump can be released and ended early
var jumpReleased = false
# Tracks if Jump release of button is buffered and to be processed
var jumpReleasedQueue = false
# Jumping power
export var JUMP_FORCE = 800

### Fall Damage
# Tracks the peak height position so it can decide if there is fall damage
var peakHeight = position.y
# Variable that determines the cutoff in height before damage starts being dealt
export var fallDamageHeight = 400
# Variable that determines damage increase rate based on falloff
export var fallDamageRate = 2

# Execute when this node loads
func initialize():
	# Add node to Main Pawn list for processes specific to Main Pawns
	if MainPawn:
		add_to_group("PlayerMainPawns")
	# Set Variables
	player_node = get_parent()
	add_collision_exception_with($EntityCollision)
	set_network_master(1)

	# Initialize required modules
	$MovementInputManager.initialize()
	$VisibilityNotifier.initialize()

	# Initialize optional modules
	if has_node("HealthManager"):
		get_node("HealthManager").initialize()
	if has_node("AttackManager"):
		get_node("AttackManager").initialize()
	if has_node("VisionManager"):
		get_node("VisionManager").initialize()

	# Set status to initialized
	initialized = true

#################################MOVEMENT FUNCTIONS

# Execute every tick
func _process(delta):
	
	# Check if out of map, and if so force teleport
	if initialized and player_node.control and !terminatePending:
		if position.y > get_node(player_node.map_path).maxHeight:

			# Reset position and inputs
			position = Vector2(0,0)
			$MovementInputManager.movement.x = 0

			# For MainPawns, prompt teleporting
			if MainPawn:
				if player_node.has_node("TeleportManager"):
					var teleportManager = player_node.get_node("TeleportManager")
					if !teleportManager.teleporting:
						teleportManager.teleporting = true
						if get_tree().is_network_server():
							if player_node.server_controlled:
								teleportManager.setTeleportingPawnServerCall(name)
						else:
							rpc_id(1, "resetPositionRPC")
							teleportManager.setTeleportingPawnToServer(name)
			# For minions and other entities, terminate
			else:
				if get_tree().is_network_server():
					if player_node.server_controlled:
						terminatePending = true
						terminatePendingAsServer()
						player_node.removePawnAsServer(name)
				else:
					terminatePending = true
					rpc_id(1, "terminatePendingServer")
					player_node.removePawnCallServer(name)

# Execute every physics tick, look at documentation for difference between _process and _physics_process tick
func _physics_process(_delta : float):
	# Handle movement
	if initialized:
		move(_delta)

# Handles movement
func move(delta):
	
	# If allowed to move
	if allowMovement:
		
		# For server
		if is_network_master():
			
			# Set gravity based on distance to floor or jumpstate so the pawn doesn't get launched on steep slopes
			$GravityRayCastCheck.force_raycast_update()
			if $GravityRayCastCheck.is_colliding() and !jumping and !appliedForce:
				gravity = Vector2(0, 7000)
			else:
				gravity = Vector2(0, 1800)

			# Prevent movement when pushing against a wall that won't budge, the velocity is nonzero even when it's pushing against a non-budging wall
			# This is because physics is wonky and should not be doing this and we are compensating
			$InclineRayCastCheck.force_raycast_update()
			if $InclineRayCastCheck.is_colliding() and !appliedForce and jumping and (($MovementInputManager.movement.x == -1 and _velocity.x > -50) or ($MovementInputManager.movement.x == 1 and _velocity.x < 50)):
				_velocity.x = 0

			# Allow left/right movement when conditionally allowed
			elif !((appliedForce and !allowForceResistance) or (appliedForce and $MovementInputManager.movement.x == 0)):
				# Applies physics (speed, gravity) to the direction
				_velocity.x = _speed * $MovementInputManager.movement.x

			### Handle jumping BEFORE the pawn is moved and physics data is updated
			# Check for a queued jump release input since sometimes releasing jump key happens in the same frame (sub frame jumping) that causes glitches
			if jumpReleasedQueue:
				if !jumpReleased and jumping:
					jumpReleased = true
				jumpReleasedQueue = false

			# If jump key is released, slow jump speed down to stop jumping
			if _velocity.y < -50 and jumpReleased:
				_velocity.y = -50
			###

			# Apply gravity
			_velocity += gravity * delta
			# Move the pawn based on calculated velocity
			_velocity = move_and_slide(_velocity, Vector2.UP, true, 4, deg2rad(90.0), true)

			# Detect if the pawn is touching another pawn (on top, side, or below)
			# This is because physics is wonky when pawns are colliding, and we need custom behavior just to compensate
			var collidingEntity = false
			for i in get_slide_count():
				var collision = get_slide_collision(i)
				if collision.collider.get_parent().has_method("verifyMovementManager") or collision.collider.has_method("verifyMovementManager"):
					collidingEntity = true
					break

			### Handle jumping AFTER the pawn is moved and physics data is updated
			# Check if the player is not supposed to be jumping anymore (reached max jump height or hit something above) and force jump release
			if _velocity.y >= -50 and jumping and !jumpReleased:
				jumpReleased = true
			###

			# Check if "Godot physics" thinks the player is in the air, which does not always work
			if !is_on_floor():
				# Set Variables
				if !airTime:
					airTime = true
					peakHeight = position.y
				elif airTime:
					# Check if position is higher than before
					if position.y < peakHeight:
						peakHeight = position.y
					elif !allowForceResistance:
						allowForceResistance = true
			# Behavior when "Godot physics" thinks the player is on the floor, which does not always work
			# Need to manually check against this and set it back, Godot 2d physics sucks
			else:
				# Godot thinks that when you are touching another entity but you're clearly in the air that youre not, so we need
				# to set custom behavior to check against it and treat other player pawns just like terrain
				$GravityRayCastCheck.force_raycast_update()
				if !collidingEntity or (collidingEntity and (_velocity.y == 0 or !jumping or $GravityRayCastCheck.is_colliding())):
					# No longer jumping, set all variables to false to signal being "on ground"
					if jumpReleased:
						jumpReleased = false
					if jumping:
						jumping = false
					if appliedForce:
						appliedForce = false
					if allowForceResistance:
						allowForceResistance = false
					if airTime:
						airTime = false
						# If you were just in the air, calculate if you need to take fall damage
						if ((position.y - peakHeight) > fallDamageHeight):
							# Check fall height and send data to server node to determine damage dealt
							if has_node("HealthManager"):
								get_node("HealthManager").calculateFallDamageServer(position.y - peakHeight, fallDamageHeight, fallDamageRate)
						# Reset the peak height so you don't take phantom fall damage
						peakHeight = position.y
			
			# Set direction of sprite to StateManager on server-side
			$StateManager.flipSprite($MovementInputManager.movement.x)

			# Send updated physics/movement information to client
			rpc_unreliable("update_state",transform, _velocity, $MovementInputManager.movement_counter, jumping, jumpReleased, $MovementInputManager.movement.x, appliedForce, peakHeight)

		# For client
		else:
			time += delta
			move_with_reconciliation(delta)

	# Freeze if not allowed to move
	else:
		_velocity = Vector2.ZERO

# Execute upon input (so far jump and shoot)
func _input(event):
	# Only execute locally so input wouldnt change other characters
	if initialized and player_node.control and !player_node.menuPressed and !get_node("../TeleportManager").teleporting and player_node.currentActivePawn == self and $StateManager.allowActions:
			# Handle jump input when pressed
			if event.is_action_pressed("jump") and !jumping and ((position.y - peakHeight) <= (fallDamageHeight * 2)):
				#call locally jumpPressed
				jumpPressed()
				#RPC to server jumpPressed
				if !get_tree().is_network_server():
					rpc_id(1, "jumpPressedRPC")
	
			# Handle jump input when key is released, which cuts the jump distance short and allows jump height control
			if event.is_action_released("jump"):
				#call locally jumpReleased
				jumpReleased()
				#RPC to server jumpReleased
				if !get_tree().is_network_server():
					rpc_id(1, "jumpReleasedRPC")

# Local jump event called from RPC
func jumpPressed():
	_velocity.y = -JUMP_FORCE
	peakHeight = position.y
	jumping = true
	jumpReleased = false
	if !allowForceResistance:
		allowForceResistance = true

# Local jump release event called from RPC
func jumpReleased():
	# Handle jump input when key is released, which cuts the jump distance short and allows jump height control
	jumpReleasedQueue = true

#################################PHYSICS FUNCTIONS

func applyForce(sourceLocation, force, forceDropoff): # Stun duration
	# -> x increases
	# v y increases
	appliedForce = true
	var forceDirection = Vector2.ZERO
	if sourceLocation.x - position.x == 0:
		forceDirection.x = 0
	else:
		forceDirection.x = (position.x - sourceLocation.x)
	$GravityRayCastCheck.force_raycast_update()
	var collidingWithEntity = false
	var test = move_and_collide(_velocity, true, true, true)
	if test and test.collider.name == "EntityCollision":
		collidingWithEntity = true
	if $GravityRayCastCheck.is_colliding() or (!$GravityRayCastCheck.is_colliding() and collidingWithEntity):
		if position.y - sourceLocation.y > 0:
			# Top half
			forceDirection.y = ((position.y - $BodyCollision.shape.height) - sourceLocation.y)
		else:
			# Bottom half
			forceDirection.y = ((position.y - ($BodyCollision.shape.height * .4)) - sourceLocation.y)
	else:
		if sourceLocation.y - position.y == 0:
			forceDirection.y = 0
		else:
			forceDirection.y = (position.y - sourceLocation.y)
	forceDirection = forceDirection.normalized()
	_velocity = Vector2((force / 2) * forceDirection.x, force * forceDirection.y)

#################################HELPER FUNCTIONS

# Initialize culling/termination of node
func terminate():
	terminateTimer.set_wait_time(5)
	# Make sure its not just a one time execution and loops infinitely
	terminateTimer.set_one_shot(true)
	# Perform inAction_loop function each execution
	terminateTimer.connect("timeout", self, "terminateTimerComplete")
	add_child(terminateTimer)
	terminateTimer.start()

# After termination timer is complete, remove self
func terminateTimerComplete():
	queue_free()

# Enable physics collision for node
func enableCollision():
	$BodyCollision.disabled = false
	$GravityRayCastCheck.enabled = true
	$InclineRayCastCheck.enabled = true

# Disable physics collision for node
func disableCollision():
	$BodyCollision.disabled = true
	$GravityRayCastCheck.enabled = false
	$InclineRayCastCheck.enabled = false

# Reset physics if physics freezing happened mid jump or movement
func resetPhysics():
	jumping = false
	peakHeight = position.y
	_velocity = Vector2.ZERO

# Verify that this is a movement manager node
func verifyMovementManager():
	return true

#################################SERVER FUNCTIONS

# Client side prediction with server reconcilliation
func move_with_reconciliation(delta):
	# Update old data with new data
	var old_transform = transform
	transform = remote_transform
	var _vel = remote_vel
	var movement_list = $MovementInputManager.movement_list
	# Parse movement inputs
	if movement_list.size() > 0:
		for i in range(movement_list.size()):
			var mov = movement_list[i]
			
			# Locally affect gravity so not too much reconcillation is done
			if $GravityRayCastCheck.is_colliding() and !jumping:
				gravity = Vector2(0, 7000)
			else:
				gravity = Vector2(0, 1800)
			
			# Move the pawn based on server's sent data
			_vel = move_and_slide(mov[2].normalized()*_speed*mov[1]/delta, Vector2.UP, true, 4, deg2rad(90.0), true)

	# Interpolate old data to the new data so the corrected movement is smoother
	interpolate(old_transform)

# Interpolation from server reconcilliation to ease client position to server's
func interpolate(old_transform):
	var scale_factor = 0.1
	var dist = transform.origin.distance_to(old_transform.origin)
	var weight = clamp(pow(2,dist/4)*scale_factor,0.0,1.0)
	transform.origin = old_transform.origin.linear_interpolate(transform.origin,weight)

# Server sending client updated physics data and state
puppet func update_state(t, velocity, ack, jumpingRPC, jumpReleasedRPC, directionRPC, appliedForceRPC, peakHeightRPC):
	self.remote_transform = t
	self.remote_vel = velocity
	self.ack = ack
	# Handles flipping the sprite based on direction
	$StateManager.flipSprite(directionRPC)
	# Set local variables from server
	jumping = jumpingRPC
	jumpReleased = jumpReleasedRPC
	appliedForce = appliedForceRPC
	peakHeight = peakHeightRPC

# Server calling position reset from teleporting onto clients
remote func resetPositionRPC():
	position = Vector2(0,0)
	rpc_unreliable("update_state",transform, _velocity, $MovementInputManager.movement_counter, jumping, jumpReleased, $MovementInputManager.movement.x, appliedForce, peakHeight)

# RPC for jump event
remote func jumpPressedRPC():
	jumpPressed()
	
# RPC for jump release event
remote func jumpReleasedRPC():
	jumpReleased()

# RPC for termination on server
func terminatePendingAsServer():
	terminatePending = true

# RPC for termination on server called from client
remote func terminatePendingServer():
	terminatePending = true

# Wrapper RPC for client calling server to apply force
remote func applyForceServer(sourceLocation, force, forceDropoff):
	applyForceAsServer(sourceLocation, force, forceDropoff)

# Wrapper RPC for server applying force locally and calling clients
func applyForceAsServer(sourceLocation, force, forceDropoff):
	applyForce(sourceLocation, force, forceDropoff)
	rpc("applyForceRPC", sourceLocation, force, forceDropoff)

# Wrapper RPC for clients receiving call from server to apply force locally
remote func applyForceRPC(sourceLocation, force, forceDropoff):
	applyForce(sourceLocation, force, forceDropoff)
