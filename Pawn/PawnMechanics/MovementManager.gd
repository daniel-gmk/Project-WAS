extends KinematicBody2D

export var MainPawn = true

### Main node for handling function, controls/input, values for UI, etc
### Multiplayer sync

### Physics
# Track if is allowed to move
var allowMovement = false
# Vector tracking movement speed
export var _speed = 250
# Vector tracking current gravity
var gravity = Vector2(0, 1800)
# Vector tracking movement/velocity
var _velocity : Vector2 = Vector2.ZERO
# Track if in the air or not
var airTime = false

### Client side prediction / Server reconciliation vars
var movement = Vector2()
master var remote_movement = Vector2()
puppet var remote_transform = Transform2D()
puppet var remote_vel = Vector2()
puppet var ack = 0 # Last movement acknowledged
var old_movement = Vector2()
var time = 0

###Jump
# Tracking if Jumping
var jumping = false
# Tracking if Jump can be released and ended early
var jumpReleased = false
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
func _ready():
	if has_node("EntityCollision"):
		add_collision_exception_with(get_node("EntityCollision"))
	if MainPawn:
		add_to_group("PlayerMainPawns")
	set_network_master(1)

func enableCollision():
	if has_node("BodyCollision"):
		get_node("BodyCollision").disabled = false
	if has_node("EntityCollision"):
		get_node("EntityCollision/EntityCollisionShape").disabled = false

func disableCollision():
	if has_node("BodyCollision"):
		get_node("BodyCollision").disabled = true
	if has_node("EntityCollision"):
		get_node("EntityCollision/EntityCollisionShape").disabled = true

func resetPhysics():
	jumping = false
	peakHeight = position.y
	_velocity = Vector2.ZERO

# Execute every tick
func _process(delta):
	if get_parent().control and MainPawn:
		# Check if out of map, and if so force teleport
		if position.y > get_node("/root/").get_node("environment").get_node("TestMap").maxHeight and !get_parent().get_node("TeleportManager").teleporting:
			position = Vector2(0,0)
			get_parent().teleportingPawn = self
			rpc_id(1, "resetPositionRPC")
			get_parent().get_node("TeleportManager").teleport()

# Execute every physics tick, look at documentation for difference between _process and _physics_process tick
func _physics_process(_delta : float):
	# Handle movement
	# Note: Probably can do this not every tick but poll for correction of location every x time
	move(_delta)

# Handles movement
func move(delta):
	if allowMovement:
		if is_network_master():
			# Applies physics (speed, gravity) to the direction
			_velocity.x = _speed * $MovementInputManager.movement.x
			# Apply gravity
			_velocity += gravity * delta
			_velocity = move_and_slide(_velocity, Vector2.UP, true, 4, deg2rad(60.0), true)
			
			if _velocity.y >= -50 and !jumpReleased:
				jumpReleased = true

			if !is_on_floor():
				if !airTime:
					airTime = true
					peakHeight = position.y
				# check if position is higher than before
				elif airTime and position.y < peakHeight:
					peakHeight = position.y
			# Stop jumping when landing on floor
			else:
				if jumping:
					jumping = false
				if airTime:
					airTime = false
					if ((position.y - peakHeight) > fallDamageHeight):
						# Check fall height and send data to server node to determine damage dealt
						get_node("/root/").get_node("1").calculateFallDamageServer(position.y - peakHeight, fallDamageHeight, fallDamageRate, str(get_parent().get_parent().name))

			rpc_unreliable("update_state",transform, _velocity, $MovementInputManager.movement_counter, jumping, jumpReleased)

		else:
			# Client code
			time += delta
			move_with_reconciliation(delta)
	else:
		_velocity = Vector2.ZERO

# Execute upon input (so far jump and shoot)
func _input(event):
	# Only execute locally so input wouldnt change other characters
	if get_parent().control and get_parent().currentActivePawn == self:
		if !get_parent().has_node("StateManager") or (get_parent().has_node("StateManager") and get_parent().get_node("StateManager").allowActions):
			# Handle jump input when pressed
			if event.is_action_pressed("jump") and !jumping:
				#call locally jumpPressed
				jumpPressed()
				#RPC to server jumpPressed
				rpc_id(1, "jumpPressedRPC")
	
			# Handle jump input when key is released, which cuts the jump distance short and allows jump height control
			if event.is_action_released("jump") and jumping and !jumpReleased and _velocity.y <= -50:
				#call locally jumpReleased
				jumpReleased()
				#RPC to server jumpReleased
				rpc_id(1, "jumpReleasedRPC")

# Local jump event called from RPC
func jumpPressed():
	_velocity.y = -JUMP_FORCE
	peakHeight = position.y
	jumping = true
	jumpReleased = false

# Local jump release event called from RPC
func jumpReleased():
	# Handle jump input when key is released, which cuts the jump distance short and allows jump height control
	_velocity.y = -50
	jumpReleased = true

#################################SERVER FUNCTIONS

# Client side prediction with server reconcilliation
func move_with_reconciliation(delta):
	var old_transform = transform
	transform = remote_transform
	var vel = remote_vel
	var movement_list = $MovementInputManager.movement_list
	if movement_list.size() > 0:
		for i in range(movement_list.size()):
			var mov = movement_list[i]
	
			vel = move_and_slide(mov[2].normalized()*_speed*mov[1]/delta, Vector2.UP, true, 4, deg2rad(60.0), true)
	
	interpolate(old_transform)

# Interpolation from server reconcilliation to ease client position to server's
func interpolate(old_transform):
	var scale_factor = 0.1
	var dist = transform.origin.distance_to(old_transform.origin)
	var weight = clamp(pow(2,dist/4)*scale_factor,0.0,1.0)
	transform.origin = old_transform.origin.linear_interpolate(transform.origin,weight)

# Server sending client updated physics data and state
puppet func update_state(t, velocity, ack, jumpingRPC, jumpReleasedRPC):
	self.remote_transform = t
	self.remote_vel = velocity
	self.ack = ack
	# Handles flipping the sprite based on direction
	if has_node("StateManager"):
		get_node("StateManager").flipSprite(velocity.x)
	jumping = jumpingRPC
	jumpReleased = jumpReleasedRPC

# Server calling position reset from teleporting onto clients
remote func resetPositionRPC():
	position = Vector2(0,0)
	rpc_unreliable("update_state",transform, _velocity, $MovementInputManager.movement_counter, jumping, jumpReleased)

# RPC for jump event
remote func jumpPressedRPC():
	jumpPressed()
	
# RPC for jump release event
remote func jumpReleasedRPC():
	jumpReleased()
