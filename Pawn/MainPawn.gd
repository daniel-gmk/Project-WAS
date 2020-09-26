extends KinematicBody2D

### Main node for handling player function, controls/input, values for UI, etc
### Multiplayer sync
# Tracking player id
var player_id
# Track allowing actions for only local player
var control = false
# Track if actions are allowed at all
var allowActions = false

### Physics
# Track if player is allowed to move
var allowMovement = false
# Vector tracking player movement speed
var _speed = 250
# Vector tracking current gravity on player
var gravity = Vector2(0, 1800)
# Vector tracking player movement/velocity
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

### Health
var minHealth = 0
var maxHealth = 10000
var health
var immortal = false

###Jump
# Tracking if Jumping
var jumping = false
# Tracking if Jump can be released and ended early
var jumpReleased = false
# Jumping power
var JUMP_FORCE = 800

### Fall Damage
# Tracks the peak height position so it can decide if there is fall damage
var peakHeight = position.y
# Variable that determines the cutoff in height before damage starts being dealt
var fallDamageHeight = 400
# Variable that determines damage increase rate based on falloff
var fallDamageRate = 2


var attackList = []
var currentSelectedAttack


### HUD
# Track the HUD component path
export var GUI_node_path : NodePath
# Use the path to grab the Main player's Health bar (Child Component of HUD) as a var
onready var health_bar_root = get_node(GUI_node_path).find_node("MainHealthBar")
# Use the path to grab the Main player's Health bar value text (Child Component of Health bar) as a var
onready var health_bar_text = health_bar_root.find_node("HealthValueText")

# Execute when this node loads
func _ready():
	# Not entirely sure if this does anything but it sets collision monitoring on for the character to detect aoe damage
	$DamageCollisionArea.monitorable = true
	add_collision_exception_with($PlayerCollision)
	# Set health
	health = maxHealth
	add_to_group("PlayerMainPawns")
	set_network_master(1)
	# Set attacks
	attackList = get_parent().mainPawnAttackList

# Execute every tick
func _process(delta):
	if control:
		# Check if out of map, and if so force teleport
		if position.y > get_node("/root/").get_node("environment").get_node("TestMap").maxHeight and !get_parent().teleporting:
			position = Vector2(0,0)
			rpc_id(1, "resetPositionRPC")
			get_parent().teleport()

# Execute every physics tick, look at documentation for difference between _process and _physics_process tick
func _physics_process(_delta : float):
	# Handle player movement
	# Note: Probably can do this not every tick but poll for correction of location every x time
	movePlayer(_delta)

# Handles movement of player
func movePlayer(delta):
	if allowMovement:
		if is_network_master():
			# Applies physics (speed, gravity) to the direction
			_velocity.x = _speed * $InputManager.movement.x
			# Apply gravity
			_velocity += gravity * delta
			_velocity = move_and_slide(_velocity, Vector2.UP, true, 4, deg2rad(60.0), false)
			
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

			rpc_unreliable("update_state",transform, _velocity, $InputManager.movement_counter, jumping, jumpReleased)

		else:
			# Client code
			time += delta
			move_with_reconciliation(delta)
	else:
		_velocity = Vector2.ZERO

# Execute upon input (so far jump and shoot)
func _input(event):
	# Only execute locally so input wouldnt change other player characters
	if control and allowActions and get_parent().currentActivePawn == self:
		# Handle jump input when pressed
		if event.is_action_pressed("jump") and !jumping:
			#call locally jumpPressedPlayer
			jumpPressedPlayer()
			#RPC to server jumpPressedPlayer
			rpc_id(1, "jumpPressedPlayerRPC")

		# Handle jump input when key is released, which cuts the jump distance short and allows jump height control
		if event.is_action_released("jump") and jumping and !jumpReleased and _velocity.y <= -50:
			#call locally jumpReleasedPlayer
			jumpReleasedPlayer()
			#RPC to server jumpReleasedPlayer
			rpc_id(1, "jumpReleasedPlayerRPC")

# Local jump event called from RPC
func jumpPressedPlayer():
	_velocity.y = -JUMP_FORCE
	peakHeight = position.y
	jumping = true
	jumpReleased = false

# Local jump release event called from RPC
func jumpReleasedPlayer():
	# Handle jump input when key is released, which cuts the jump distance short and allows jump height control
	_velocity.y = -50
	jumpReleased = true

# Handles when damage is taken
func takeDamage(damage):
	if !immortal:
		health -= damage
		# Update health bar HUD
		if get_tree().get_network_unique_id() == player_id:
			health_bar_root.value = health
			health_bar_text.text = String(round(health))
		# Dead if health falls below min value
		if health <= minHealth:
			death()

# Handles when dead, not implemented yet since gamemode should be created first
func death():
	print("I died")

#################################SERVER FUNCTIONS

# Client side prediction with server reconcilliation
func move_with_reconciliation(delta):
	var old_transform = transform
	transform = remote_transform
	var vel = remote_vel
	var movement_list = $InputManager.movement_list
	if movement_list.size() > 0:
		for i in range(movement_list.size()):
			var mov = movement_list[i]
	
			vel = move_and_slide(mov[2].normalized()*_speed*mov[1]/delta, Vector2.UP, true, 4, deg2rad(60.0), false)
	
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
	if velocity.x >= 1:
		$Sprite.flip_h = false
	elif velocity.x <= -1:
		$Sprite.flip_h = true
	jumping = jumpingRPC
	jumpReleased = jumpReleasedRPC

# Server calling position reset from teleporting onto clients
remote func resetPositionRPC():
	position = Vector2(0,0)
	rpc_unreliable("update_state",transform, _velocity, $InputManager.movement_counter, jumping, jumpReleased)

# RPC for jump event
remote func jumpPressedPlayerRPC():
	jumpPressedPlayer()
	
# RPC for jump release event
remote func jumpReleasedPlayerRPC():
	jumpReleasedPlayer()

# Server receives call to locally execute damage and also replicate damage to clients
func serverBroadcastDamageRPC(damage):
	takeDamage(damage)
	rpc("takeDamageRPC", damage)

# I abstracted takeDamage as a local call instead of just making it a remote function in case I want to make local
# calls down the road and not quite sure if I need to yet.
remote func takeDamageRPC(damage):
	takeDamage(damage)

#################################UI FUNCTIONS

# Set UI for the player
func initiate_ui():
	# Set Main player's Health Bar
	health_bar_root.max_value = maxHealth
	health_bar_root.min_value = minHealth
	health_bar_root.value = health
	health_bar_text.text = String(health)
