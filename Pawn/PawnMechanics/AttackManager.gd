extends Node2D

### Attack
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

### Reticule/charging UI, this specific HUD component is separate from the rest of the GUI/HUD, too lazy to move tbh
# Track the actual Reticule component within the reticule parent as a var
var chargeProgress
# Static value for tracking the charge value before it fills the reticule
var reticule_max = 2

var skill_data

export var attackList = []
var currentSelectedAttack

export var skilldata_file_path = "res://Skills/SkillData.json"
var player_node

# Called when the node enters the scene tree for the first time.
func _ready():
	player_node = get_parent().get_parent()
	chargeProgress = get_node("ReticuleAnchor/ChargeReticule")
	
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
	if get_parent().MainPawn:
		# Set attacks
		attackList = player_node.mainPawnAttackList # Replace with logic to pull from spell selection
	currentSelectedAttack = attackList[0]

func _process(delta):
	# Locally render the reticule every tick, optimize this to only be needed when attacking
	_render_reticule()

func _physics_process(_delta : float):
	# Execute only for local player
	if player_node.control:
		if get_node("../StateManager").allowActions:
			# Charge attack if holding charge button for shooting projectile
			if _attack_clicked:
				_attack_power += _delta
			
			# If the player has been holding the attack button long enough it auto fires
			if _attack_power >= _auto_attack_power:
				# Same standard typeless attack as line 120
				shoot(currentSelectedAttack)

func _input(event):
	if player_node.control and !player_node.menuPressed and !player_node.get_node("TeleportManager").teleporting and player_node.currentActivePawn == get_parent():
		if get_node("../StateManager").allowActions:
			# Handle charging projectile strength when shoot input is pressed and held
			if event.is_action_pressed("shoot") and !player_node.selectMinion:
					_attack_clicked = true
					# Shows reticule when attacking
					chargeProgress.max_value = reticule_max
					chargeProgress.visible = true
		
			# Handle launching projectile based on charge strength when input is let go
			elif event.is_action_released("shoot") and !player_node.selectMinion:
				if _attack_clicked:
					# Standard typeless attack
					shoot(currentSelectedAttack)

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
	# Grab position of reticule as starting position of projectile
	
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
	
	
	if get_tree().is_network_server():
		if player_node.server_controlled:
			summonProjectileAsServer(localData, remoteData)
	else:
		# Summon projectile locally but have it just disappear on impact
		summonProjectile(localData)
		# Broadcast RPC so projectile can be shown to other players/server
		rpc_id(1, "summonProjectileServer", localData, remoteData)
	
	
	resetAttack()

func resetAttack():
	_attack_power = 0
	_attack_clicked = false
	# Hide the reticule now that firing is done
	chargeProgress.visible = false
	chargeProgress.value = 0

# Render the reticle so it shows projectile charge
func _render_reticule():
	# Change rotation of reticule to mouse
	get_node("ReticuleAnchor").look_at(get_global_mouse_position())
	# Change charge HUD display so it fills up as charging
	if _attack_clicked:
		chargeProgress.value = clamp(_attack_power + (1.05 * _auto_attack_power), (1.05 * _auto_attack_power), reticule_max)

# Send data of a shot projectile and simulate across server to other players
func summonProjectileAsServer(localData, remoteData):
	# If server
	summonProjectile(remoteData)
	# Loop through clients and launch projectile to each
	rpc("summonProjectileRPC", localData, remoteData["Network_Data"]["Caster_PlayerID"])

# Send data of a shot projectile and simulate across server to other players
remote func summonProjectileServer(localData, remoteData):
	# If server
	summonProjectile(remoteData)
	# Loop through clients and launch projectile to each
	rpc("summonProjectileRPC", localData, remoteData["Network_Data"]["Caster_PlayerID"])

# Send data of a shot projectile and simulate across server to other players
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

static func merge_dict(target, patch):
	var result = target
	for key in patch:
		if typeof(patch[key]) == 18 and target.has(key):
			result[key] = merge_dict(target[key], patch[key])
		else:
			result[key] = patch[key]
	return result
