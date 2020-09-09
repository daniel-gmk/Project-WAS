extends KinematicBody2D

### Main node for handling player function, controls/input, values for UI, etc

### Multiplayer sync
# Tracking player id
var player_id
# Track allowing actions for only local player
var control = false

### Physics
# Initial position/spawn in map TO BE REPLACED
var pos = Vector2(1000, 100)
# Track whether to utilize snap physics on ground for move_and_slide_with_snap
var snap = Vector2(0, 32)
# Vector tracking player movement speed
export (Vector2) var _speed = Vector2(250, 360)
# Vector tracking gravity on player
export (Vector2) var gravity = Vector2(0, 4800)
# Vector tracking player movement/velocity
var _velocity : Vector2 = Vector2.ZERO

### Health
var minHealth = 0
var maxHealth = 10000
var health

###Jump
# Tracking if Jumping
var jumping
# Jumping power
var JUMP_FORCE = 1500
# Tracking jump direction (left or right)
var jump_direction = Vector2.ZERO

### Fall Damage
# Tracks the peak height position so it can decide if there is fall damage
var peakHeight
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
	# Set spawn position
	self.position = pos
	# Not entirely sure if this does anything but it sets collision monitoring on for the character to detect aoe damage
	$DamageCollisionArea.monitorable = true
	# Set health
	health = maxHealth

func initiate_ui():
	# Set Main player's Health Bar
	health_bar_root.max_value = maxHealth
	health_bar_root.min_value = minHealth
	health_bar_root.value = health
	health_bar_text.text = String(health)


# Execute every tick
func _process(delta):
	if control:
		# Locally render the reticule every tick, optimize this to only be needed when attacking
		_render_reticule()

# Execute upon input (so far jump and shoot)
func _input(event):
	
	# Only execute locally so input wouldnt change other player characters
	if control:
		
		# Handle jump input when pressed
		if event.is_action_pressed("jump") and is_on_floor():
			snap = Vector2()
			jump_direction = Vector2(Input.get_action_strength("right") - Input.get_action_strength("left"), 0)
			_velocity.y += -JUMP_FORCE
			peakHeight = position.y
			jumping = true
			rising = true

		# Handle jump input when key is released, which cuts the jump distance short and allows jump height control
		if event.is_action_released("jump") and jumping and _velocity.y <= -100:
			_velocity.y = -100

		# Handle charging projectile strength when shoot input is pressed and held
		if event.is_action_pressed("shoot"):
				_attack_clicked = true
				# Shows reticule when attacking
				chargeProgress = reticule_anchor.find_node("chargeReticule")
				chargeProgress.max_value = reticule_max
				chargeProgress.visible = true

		# Handle launching projectile based on charge strength when input is let go
		elif event.is_action_released("shoot"):
			if _attack_clicked:
				# Standard typeless attack
				shoot(500, 42, true, false)

# Execute every physics tick, look at documentation for difference between _process and _physics_process tick
func _physics_process(_delta : float):
	
	# Execute only for local player
	if control:
		
		# Charge attack if holding charge button for shooting projectile
		if _attack_clicked:
			_attack_power += _delta
		
		# If the player has been holding the attack button long enough it auto fires
		if _attack_power >= _auto_attack_power:
			# Same standard typeless attack as line 120
			shoot(500, 42, true, false)
		
		# If starting to fall, make sure ground snap physics is re-enabled for good sliding/snap physics in movement
		if _velocity.y >= 0 and !is_on_floor():
			snap = Vector2(0, 32)
			# At peak height, detect as variable for calculating fall damage
			if rising == true:
				peakHeight = position.y
				rising = false
			
		# Handle player movement
		# Note: Probably can do this not every tick but poll for correction of location every x time
		movePlayer()

		# Handles flipping the sprite based on direction
		if _velocity.x >= 1:
			$Sprite.flip_h = false
		elif _velocity.x <= -1:
			$Sprite.flip_h = true

# Handles movement of player
func movePlayer():
	# Grab which direction (left, right) from the player
	var input_direction = _get_input_direction()
	
	# Applies physics (speed, gravity) to the direction
	_velocity = _calculate_move_velocity(_velocity, input_direction, _speed)
	# Applies Godot's native collision detection
	_velocity = move_and_slide_with_snap(_velocity, snap, Vector2.UP, true, 4, deg2rad(90.0))
	# Broadcasts resulting location/position to RPC (players, server)
	rpc_unreliable("updateRPCposition", position, player_id)

	# Stop jumping when landing on floor
	if jumping and is_on_floor() and ((position.y - peakHeight) > fallDamageHeight):
		jumping = false
		jump_direction = Vector2.ZERO
		# Check fall height and send data to server node to determine damage dealt
		get_node("/root/").get_node("1").rpc_id(1, "calculateFallDamageServer", position.y - peakHeight, fallDamageHeight, fallDamageRate, player_id)

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

# Send update of position to server/players
remote func updateRPCposition(pos, pid):
	var root  = get_node("/root/")
	var pnode = root.get_node(str(pid)).get_node("player").get_node("playerPhysicsBody")
	
	pnode.position = pos

#################################HELPER FUNCTIONS

# Grabs direction (left, right) from the player, or if jumping, the original direction when pressed
func _get_input_direction() -> Vector2:
	if is_on_floor():
		return Vector2(Input.get_action_strength("right") - Input.get_action_strength("left"), 0)
	elif jumping:
		return jump_direction
	else:
		return Vector2(0,0)

# Applies physics (speed, gravity) to the direction
func _calculate_move_velocity(
		linear_velocity: Vector2,
		direction: Vector2,
		speed: Vector2
	):
		var new_velocity := linear_velocity
		new_velocity.x = speed.x * direction.x
		
		# Apply gravity
		new_velocity += gravity * get_physics_process_delta_time()
		
		# If player is jumping
		if direction.y == -1:
			new_velocity.y = speed.y * direction.y
		
		return new_velocity

# Render the reticle so it shows projectile charge
func _render_reticule():
	# Change rotation of reticule to mouse
	reticule_anchor.look_at(get_global_mouse_position())
	# Change charge HUD display so it fills up as charging
	if _attack_clicked:
		chargeProgress.value = clamp(_attack_power + (1.05 * _auto_attack_power), (1.05 * _auto_attack_power), reticule_max)
