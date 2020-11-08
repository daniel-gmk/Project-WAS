extends Node2D

##### This node allows attacking capabilities for the parent node that it is attached to

### Node Management
# Variables that manage the modularity of the module
# Tracks the main player node that manages this node's parent
var player_node
# Tracks whether this node is initialized
var initialized = false

### Attack Handler
# Variables pertaining to management of attacks
# All available attacks in array
export var attackList = []
# Current selected Attack from attack array
var currentSelectedAttack
# Skill data stored locally
export var skilldata_file_path = "res://Skills/SkillData.json"
# Extracted skill data to local memory
var skill_data

### Attack
# Variables pertaining to a single attack
# Allow setting attack projectile 
# Plan to consolidate remaining data below so server sends this data to client for various attacks
# How long the player charged the attack
var _attack_power : float = 0
# Multiplier to the force of projectile
var _attack_scale : float = 3
# Charge limit for player before auto attack
onready var _auto_attack_power : float = 1
# Whether player released shot
var _attack_clicked : bool = false

### UI
# Reticule/charging UI, this specific HUD component is separate from the rest of the GUI/HUD
# Track the actual Reticule component within the reticule parent as a var
var chargeProgress
# Static value for tracking the charge value before it fills the reticule
var reticule_max = 2

# Called to start the module/node
func initialize():
	# Set node values
	player_node = get_parent().player_node
	chargeProgress = get_node("ReticuleAnchor/ChargeReticule")

	# Load local skill data file
	var file = File.new()
	if file.open(skilldata_file_path, file.READ) != OK:
		print("error opening file")
		return
	var file_text = file.get_as_text()
	file.close()
	var file_parse = JSON.parse(file_text)
	if file_parse.error != OK:
		print("error parsing file")
		return
	skill_data = file_parse.result
	
	# Set Attack List for MainPawns, the minions' are hardcoded
	if get_parent().MainPawn:
		# Set attacks
		attackList = player_node.mainPawnAttackList # Replace with logic to pull from spell selection

	# Set current attack to the first attack on the attack list
	currentSelectedAttack = attackList[0]

	# Sets node as initialized
	initialized = true

# Runs every frame
func _process(delta):
	if initialized:
		# Locally render the reticule every tick, optimize this to only be needed when attacking
		_render_reticule()

# Runs every physics frame
func _physics_process(_delta : float):
	# Execute conditionally, helper function below
	if actionAllowed():
		# Charge attack if holding charge button for shooting projectile
		if _attack_clicked:
			_attack_power += _delta
		
		# If the player has been holding the attack button long enough it auto fires
		if _attack_power >= _auto_attack_power:
			# Same standard typeless attack as line 120
			shoot(currentSelectedAttack)

func _input(event):
	# Execute conditionally, helper function below
	if actionAllowed():
		# If not selecting a minion, otherwise it also shoots when selecting a minion location
		if !player_node.selectMinion:
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
					shoot(currentSelectedAttack)

		# Handles scrolling input for rotating selected attack
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == BUTTON_WHEEL_UP or event.button_index == BUTTON_WHEEL_DOWN:
				var currentSelectedAttack = currentSelectedAttack
				var currentAttackpos = attackList.find(currentSelectedAttack)
				var attackListLastPos = attackList.size()-1
				if currentAttackpos == -1:
					return
				if event.button_index == BUTTON_WHEEL_UP:
					if currentAttackpos == attackListLastPos:
						currentSelectedAttack = attackList[0]
					else:
						currentSelectedAttack = attackList[currentAttackpos+1]
				elif event.button_index == BUTTON_WHEEL_DOWN:
					if currentAttackpos == 0:
						currentSelectedAttack = attackList[attackListLastPos]
					else:
						currentSelectedAttack = attackList[currentAttackpos-1]

# Handles attacking, for now using a base projectile
func shoot(skill_type):
	## This is local execution of projectile
	# Get reticule to find position of reticule
	var reticule := get_node("ReticuleAnchor/Reticule")
	
	# Fill data parsed from local file
	
	var physicsData = {
		"Starting_Position": reticule.global_position,
		"Attacker_Position": get_parent().global_position,
		"Attack_Power": _attack_power,
		"Attack_Scale": _attack_scale,
	}
	
	var localData = {
		"Skill_Name": skill_type,
		"Physics_Data": physicsData,
		"Network_Data": {
			"Remote_Call": false
		}
	}
	
	var remoteData = {
		"Skill_Name": skill_type,
		"Physics_Data": physicsData,
		"Network_Data": {
			"Remote_Call": true,
			"Caster_PlayerID": int(player_node.clientName)
		}
	}
	
	# Shoot
	if get_tree().is_network_server():
		if player_node.server_controlled:
			summonProjectileAsServer(localData, remoteData)
	else:
		# Summon projectile locally but have it just disappear on impact
		summonProjectile(localData)
		# Broadcast RPC so projectile can be shown to other players/server
		rpc_id(1, "summonProjectileServer", localData, remoteData)

	# Reset attack
	resetAttack()

func resetAttack():
	# Reset attack charge parameters
	_attack_power = 0
	_attack_clicked = false
	# Hide the reticule now that firing is done
	if chargeProgress != null:
		chargeProgress.visible = false
		chargeProgress.value = 0

# Render the reticle so it shows projectile charge
func _render_reticule():
	# Change rotation of reticule to mouse
	get_node("ReticuleAnchor").look_at(get_global_mouse_position())
	# Change charge HUD display so it fills up as charging
	if _attack_clicked:
		chargeProgress.value = clamp(_attack_power + (1.05 * _auto_attack_power), (1.05 * _auto_attack_power), reticule_max)

# Handle projectile shooting across RPC
# Wrapper shooting as P2P server
func summonProjectileAsServer(localData, remoteData):
	summonProjectileServerCall(localData, remoteData)
# Wrapper calling server from client
remote func summonProjectileServer(localData, remoteData):
	summonProjectileServerCall(localData, remoteData)
# Server calling locally and broadcast to clients
func summonProjectileServerCall(localData, remoteData):
	# Call locally as server
	summonProjectile(remoteData)
	# Call a "visual-only" projectile to all other clients
	rpc("summonProjectileRPC", localData, remoteData["Network_Data"]["Caster_PlayerID"])

# Calling a "visual-only" projectile from server to all other clients except local player
remote func summonProjectileRPC(localData, caster_playerID):
	if caster_playerID != get_tree().get_network_unique_id():
		summonProjectile(localData)

# Launches projectile/attack
func summonProjectile(data):
	var skill = skill_data[data["Skill_Name"]]
	data = merge_dict(data, skill)
	var attackData = data["Attack_Data"]
	var physicsData = data["Physics_Data"]
	var networkData = data["Network_Data"]
	# Spawn instance of projectile node
	var scene_dir = "res://Skills/" + data["Skill_Name"] + ".tscn"
	var projectile_scene = load(scene_dir)
	var new_projectile := projectile_scene.instance() as RigidBody2D
	# Initialize other variables for Projectile, details on the variables are on Projectile.gd
	new_projectile.damage = attackData["Damage"]
	new_projectile.explosion_radius = attackData["Explosion_Radius"]
	new_projectile.damage_falloff = attackData["Damage_Falloff"]
	new_projectile.ignoreCaster = data["Ignore_Attacker"]
	new_projectile.casterID = get_parent()
	new_projectile.add_collision_exception_with(get_parent())
	# Apply reticule position as projectile's starting position
	new_projectile.knockback_force = physicsData["Knockback_Force"]
	new_projectile.knockback_dropoff = physicsData["Knockback_Dropoff"]
	new_projectile.global_position = physicsData["Starting_Position"]
	# Apply force/velocity to the projectile to launch based on charge power and direction of aim
	new_projectile.linear_velocity = (physicsData["Starting_Position"] - physicsData["Attacker_Position"]) * physicsData["Projectile_Speed"] * (physicsData["Attack_Power"] * physicsData["Attack_Scale"])
	# Projectile is server so set variable
	new_projectile.server = networkData["Remote_Call"]
	# Bring the configured projectile into the scene/world
	get_node("/root/environment").add_child(new_projectile)

# Helper function to merge dictionaries, Godot doesn't have one natively...
static func merge_dict(target, patch):
	var result = target
	for key in patch:
		if typeof(patch[key]) == 18 and target.has(key):
			result[key] = merge_dict(target[key], patch[key])
		else:
			result[key] = patch[key]
	return result

# Helper function showing whether the player can perform actions
func actionAllowed():
	if (initialized 
		and player_node.control 
		and !player_node.menuPressed 
		and !player_node.get_node("TeleportManager").teleporting 
		and player_node.currentActivePawn == get_parent()
		and get_parent().get_node("StateManager").allowActions):
			return true
	else:
		return false
