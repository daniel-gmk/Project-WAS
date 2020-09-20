extends KinematicBody2D

### Main node for handling player function, controls/input, values for UI, etc
### Multiplayer sync
# Tracking player id
var player_id
# Track allowing actions for only local player
var control = false

var allowActions = true

### Physics
var allowMovement = true
# Initial position/spawn in map TO BE REPLACED
var pos = Vector2(1000, 100)
# Track whether to utilize snap physics on ground for move_and_slide_with_snap
var snap = Vector2(0, 64)
# Vector tracking player movement speed
var _speed = 250
# Vector tracking current gravity on player
var gravitydefault = Vector2(0, 3600)
var gravity = Vector2(0, 1800)
# Vector tracking player movement/velocity
var _velocity : Vector2 = Vector2.ZERO
# Track when falling NOT from jumping
var falling = true


var movement = Vector2()
master var remote_movement = Vector2()
puppet var remote_transform = Transform2D()
puppet var remote_vel = Vector2()
# Client server reconciliation vars
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
# Jumping power
var JUMP_FORCE = 800

### Fall Damage
# Tracks the peak height position so it can decide if there is fall damage
var originalHeight = position.y
var peakHeight = position.y
# Tracks when to stop recording peak height and also when character is rising
var rising
# Variable that determines the cutoff in height before damage starts being dealt
var fallDamageHeight = 400
# Variable that determines damage increase rate based on falloff
var fallDamageRate = 2

### Attack
# Allow setting attack projectile 
# Plan to replace this twice, once with basic attack, other with dynamic spellbook selection
export var weapon_projectile : PackedScene
# Plan to consolidate remaining data below so server sends this data to client for various attacks
# How long the player charged the attack
var _attack_power : float = 0
# Multiplier to the force of projectile
var _attack_scale : float = 3
# Charge limit for player before auto attack
onready var _auto_attack_power : float = 1
# Whether player released shot
var _attack_clicked : bool = false

### Reticule/charging UI, this specific HUD component is separate from the rest of the GUI/HUD, too lazy to move tbh
# Expose the actual HUD component's path
export var _reticule_anchor_node_path : NodePath
# Use the path to grab the base HUD component (the reticule's parent) as a var
onready var reticule_anchor : Node2D = get_node(_reticule_anchor_node_path)
# Track the actual Reticule component within the reticule parent as a var
var chargeProgress
# Static value for tracking the charge value before it fills the reticule
var reticule_max = 2

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
	chargeProgress = reticule_anchor.find_node("chargeReticule")
	set_network_master(1)

func initiate_ui():
	# Set Main player's Health Bar
	health_bar_root.max_value = maxHealth
	health_bar_root.min_value = minHealth
	health_bar_root.value = health
	health_bar_text.text = String(health)

# Execute every tick
func _process(delta):
	if control:
		# Check if out of map, and if so force teleport
		if position.y > get_node("/root/").get_node("environment").get_node("TestMap").maxHeight + 100 and !get_parent().teleporting:
			position = Vector2(0,0)
			get_parent().teleport()
		# Locally render the reticule every tick, optimize this to only be needed when attacking
		_render_reticule()

# Execute upon input (so far jump and shoot)
func _input(event):
	# Only execute locally so input wouldnt change other player characters
	if control and allowActions and get_parent().currentActivePawn == self:
		# Handle jump input when pressed
#		if event.is_action_pressed("jump") and is_on_floor():
#			snap = Vector2()
#			gravity = Vector2(0, 1800)
#			_velocity.y = -JUMP_FORCE
#			peakHeight = position.y
#			jumping = true
#			rising = true
#
#		# Handle jump input when key is released, which cuts the jump distance short and allows jump height control
#		if event.is_action_released("jump") and jumping and _velocity.y <= -50:
#			_velocity.y = -50

		# Handle charging projectile strength when shoot input is pressed and held
		if event.is_action_pressed("shoot"):
				_attack_clicked = true
				# Shows reticule when attacking
				chargeProgress.max_value = reticule_max
				chargeProgress.visible = true

		# Handle launching projectile based on charge strength when input is let go
		elif event.is_action_released("shoot"):
			if _attack_clicked:
				# Standard typeless attack
				shoot(500, 42, true, false)

# Execute every physics tick, look at documentation for difference between _process and _physics_process tick
func _physics_process(_delta : float):
	if !is_on_floor() and !jumping:
		if falling == false:
			falling = true
			peakHeight = position.y
	else:
		falling = false
	# Execute only for local player
	if control and allowActions:
		
		# Charge attack if holding charge button for shooting projectile
		if _attack_clicked:
			_attack_power += _delta
		
		# If the player has been holding the attack button long enough it auto fires
		if _attack_power >= _auto_attack_power:
			# Same standard typeless attack as line 120
			shoot(500, 42, true, false)
		
		# If starting to fall, make sure ground snap physics is re-enabled for good sliding/snap physics in movement
		if _velocity.y >= 0 and !is_on_floor():
			# At peak height, detect as variable for calculating fall damage
			if rising == true:
				peakHeight = position.y
				rising = false

		# Handles flipping the sprite based on direction
		if _velocity.x >= 1:
			$Sprite.flip_h = false
		elif _velocity.x <= -1:
			$Sprite.flip_h = true

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
			_velocity = move_and_slide_with_snap(_velocity, snap, Vector2.UP, true, 4, deg2rad(60.0), false)
			
			rpc_unreliable("update_state",transform, _velocity, $InputManager.movement_counter)
		else:
			# Client code
			time += delta
			move_with_reconciliation(delta)
	else:
		_velocity = Vector2.ZERO

	# Stop jumping when landing on floor
#	if (jumping or falling) and is_on_floor():
#		if jumping:
#			jumping = false
#		if falling:
#			falling = false
#		snap = Vector2(0, 64)
#		gravity = gravitydefault
#		_velocity.y = 0 + (gravity.y * delta)
#		if ((position.y - peakHeight) > fallDamageHeight):
#			# Check fall height and send data to server node to determine damage dealt
#			get_node("/root/").get_node("1").rpc_id(1, "calculateFallDamageServer", position.y - peakHeight, fallDamageHeight, fallDamageRate, player_id)

# Handles attacking, for now using a base projectile
func shoot(damage, explosion_radius, damage_falloff, ignoreSelf):
	## This is local execution of projectile
	# Get reticule to find position of reticule
	var reticule := reticule_anchor.find_node("Reticule")
	# Grab position of reticule as starting position of projectile
	var reticule_position = reticule.global_position

	# Summon projectile locally but have it just disappear on impact
	get_node("/root/").get_node("1").summonProjectile(reticule_position, global_position, 30, _attack_power, _attack_scale, false, 0, 0, false, ignoreSelf, player_id)
	# Broadcast RPC so projectile can be shown to other players/server
	get_node("/root/").get_node("1").rpc_id(1, "summonProjectileServer", reticule_position, global_position, 30, _attack_power, _attack_scale, true, damage, explosion_radius, damage_falloff, ignoreSelf, player_id)
	# Reset the charge
	_attack_power = 0
	_attack_clicked = false
	# Hide the reticule now that firing is done
	chargeProgress.visible = false
	chargeProgress.value = 0

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
# Server receives call to locally execute damage and also replicate damage to clients
func serverBroadcastDamageRPC(damage):
	takeDamage(damage)
	rpc("takeDamageRPC", damage)

# I abstracted takeDamage as a local call instead of just making it a remote function in case I want to make local
# calls down the road and not quite sure if I need to yet.
remote func takeDamageRPC(damage):
	takeDamage(damage)




func move_with_reconciliation(delta):
	var old_transform = transform
	transform = remote_transform
	var vel = remote_vel
	var movement_list = $InputManager.movement_list
	if movement_list.size() > 0:
		for i in range(movement_list.size()):
			var mov = movement_list[i]
			vel = move_and_slide_with_snap(mov[2].normalized()*_speed*mov[1]/delta, Vector2(0, 64), Vector2.UP, true, 4, deg2rad(60.0), false) # watch snap, especially for jump issues
	
	interpolate(old_transform)

func interpolate(old_transform):
	var scale_factor = 0.1
	var dist = transform.origin.distance_to(old_transform.origin)
	var weight = clamp(pow(2,dist/4)*scale_factor,0.0,1.0)
	transform.origin = old_transform.origin.linear_interpolate(transform.origin,weight)

puppet func update_state(t, velocity, ack):
	self.remote_transform = t
	self.remote_vel = velocity
	self.ack = ack




#################################HELPER FUNCTIONS

# Render the reticle so it shows projectile charge
func _render_reticule():
	# Change rotation of reticule to mouse
	reticule_anchor.look_at(get_global_mouse_position())
	# Change charge HUD display so it fills up as charging
	if _attack_clicked:
		chargeProgress.value = clamp(_attack_power + (1.05 * _auto_attack_power), (1.05 * _auto_attack_power), reticule_max)
