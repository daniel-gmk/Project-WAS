extends KinematicBody2D

### Main node for handling player function, controls/input, values for UI, etc

### Multiplayer sync
# Tracking player id
var player_id
# Track allowing actions for only local player
var control = false

### Physics
# Initial position/spawn in map TO BE REPLACED
var pos = Vector2(2100, 1400)
# Track whether to utilize snap physics on ground for move_and_slide_with_snap
var snap = Vector2(0, 32)
# Vector tracking player movement speed
export (Vector2) var _speed = Vector2(400, 600)
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
var JUMP_FORCE = 2000
# Tracking jump direction (left or right)
var jump_direction = Vector2.ZERO

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
	
	# Set health
	health = maxHealth
	
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
			jumping = true

		# Handle jump input when key is released, which cuts the jump distance short and allows jump height control
		if event.is_action_released("jump") and jumping and _velocity.y <= -500:
			_velocity.y = -500

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
				shoot()

# Execute every physics tick, look at documentation for difference between _process and _physics_process tick
func _physics_process(_delta : float):
	
	# Execute only for local player
	if control:
		
		# Charge attack if holding charge button for shooting projectile
		if _attack_clicked:
			_attack_power += _delta
		
		# If the player has been holding the attack button long enough it auto fires
		if _attack_power >= _auto_attack_power:
			shoot()
		
		# If starting to fall, make sure ground snap physics is re-enabled for good sliding/snap physics in movement
		if _velocity.y >= 0 and !is_on_floor():
			snap = Vector2(0, 32)
			
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
	if jumping and is_on_floor():
		jumping = false
		jump_direction = Vector2.ZERO

# Handles attacking, for now using a base projectile
func shoot():
	## This is local execution of projectile
	# Spawn projectile
	var reticule := reticule_anchor.find_node("Reticule")
	# Grab position of reticule as starting position of projectile
	var reticule_position = reticule.global_position

	# If server, launch locally and broadcast to all
	if get_tree().is_network_server():
		summonProjectile(reticule_position, global_position, 30, _attack_power, _attack_scale, true)
		# Loop through clients and launch projectile to each
		rpc("summonProjectileRPC", reticule_position, global_position, 30, _attack_power, _attack_scale, player_id)
	else:
		# Do the whole above process to RPC with the same parameters so projectile can be shown to other players/server
		rpc_id(1, "summonProjectileRPC", reticule_position, global_position, 30, _attack_power, _attack_scale, player_id)
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
	health_bar_root.value = health
	health_bar_text.text = String(health)
	
	# Dead if health falls below min value
	if health <= minHealth:
		death()

# Handles when dead
func death():
	print("I died")

#################################SERVER FUNCTIONS

# Send update of position to server/players
remote func updateRPCposition(pos, pid):
	var root  = get_parent().get_parent()
	var pnode = root.get_node(str(pid)).find_node("playerPhysicsBody")
	
	pnode.position = pos

# Send data of a shot projectile and simulate across server to other players
remote func summonProjectileRPC(startpos, position2, speed, attack_power, attack_scale, pid):
	# If server
	if get_tree().is_network_server():	
		summonProjectile(startpos, position2, speed, attack_power, attack_scale, true)
		# Loop through clients and launch projectile to each
		rpc("summonProjectileRPC", startpos, position2, speed, attack_power, attack_scale, 2)
	else:
		summonProjectile(startpos, position2, speed, attack_power, attack_scale, false)

#################################HELPER FUNCTIONS

# Launches projectile/attack
func summonProjectile(startpos, position2, speed, attack_power, attack_scale, local):
	# Spawn instance of projectile node
	var new_projectile := weapon_projectile.instance() as RigidBody2D
	# Apply reticule position as projectile's starting position
	new_projectile.global_position = startpos
	# Apply force/velocity to the projectile to launch based on charge power and direction of aim
	new_projectile.linear_velocity = (startpos - position2) * speed * (attack_power * attack_scale)
	# Projectile is server so set variable
	new_projectile.local = local
	# Bring the configured projectile into the scene/world
	get_parent().add_child(new_projectile)

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

func _render_reticule():
	# Change rotation of reticule to mouse
	reticule_anchor.look_at(get_global_mouse_position())
	# Change charge HUD display so it fills up as charging
	if _attack_clicked:
		chargeProgress.value = clamp(_attack_power + (1.05 * _auto_attack_power), (1.05 * _auto_attack_power), reticule_max)
