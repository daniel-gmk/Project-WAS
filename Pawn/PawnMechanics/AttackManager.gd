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
	if player_node.control and !player_node.get_node("TeleportManager").teleporting and player_node.currentActivePawn == get_parent():
		if get_node("../StateManager").allowActions:
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

		# Zoom, this will be turned off for non-spectators eventually
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
	var skill = skill_data[skill_type]
	var damage = skill['Damage']
	var explosion_radius = skill['Explosion_Radius']
	var damage_falloff = skill['Damage_Falloff']
	var ignoreSelf = skill['Ignore_Self']
	var projectile_speed = skill['Projectile_Speed']
	## This is local execution of projectile
	# Get reticule to find position of reticule
	var reticule := get_node("ReticuleAnchor/Reticule")
	# Grab position of reticule as starting position of projectile
	var reticule_position = reticule.global_position

	# Summon projectile locally but have it just disappear on impact
	summonProjectile(reticule_position, get_parent().global_position, projectile_speed, _attack_power, _attack_scale, false, 0, 0, false, ignoreSelf, skill_type)
	# Broadcast RPC so projectile can be shown to other players/server
	rpc_id(1, "summonProjectileServer", reticule_position, get_parent().global_position, projectile_speed, _attack_power, _attack_scale, true, damage, explosion_radius, damage_falloff, ignoreSelf, skill_type)
	# Reset the charge
	_attack_power = 0
	_attack_clicked = false
	# Hide the reticule now that firing is done
	chargeProgress.visible = false
	chargeProgress.value = 0

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
remote func summonProjectileServer(startpos, position2, speed, attack_power, attack_scale, isServer, damage, explosion_radius, damage_falloff, ignoreSelf, skill_type):
	# If server
	summonProjectile(startpos, position2, speed, attack_power, attack_scale, true, damage, explosion_radius, damage_falloff, ignoreSelf, skill_type)
	# Loop through clients and launch projectile to each
	rpc("summonProjectileRPC", startpos, position2, speed, attack_power, attack_scale, false, 0, 0, false, ignoreSelf, skill_type)

# Send data of a shot projectile and simulate across server to other players
remote func summonProjectileRPC(startpos, position2, speed, attack_power, attack_scale, isServer, damage, explosion_radius, damage_falloff, ignoreSelf, skill_type):
	summonProjectile(startpos, position2, speed, attack_power, attack_scale, false, 0, 0, false, ignoreSelf, skill_type)

# Launches projectile/attack
func summonProjectile(startpos, position2, speed, attack_power, attack_scale, isServer, damage, explosion_radius, damage_falloff, ignoreSelf, skill_type):
	# Spawn instance of projectile node
	var scene_dir = "res://Skills/" + skill_type + ".tscn"
	var projectile_scene = load(scene_dir)
	var new_projectile := projectile_scene.instance() as RigidBody2D
	# Initialize other variables for Projectile, details on the variables are on Projectile.gd
	new_projectile.damage = damage
	new_projectile.explosion_radius = explosion_radius
	new_projectile.damage_falloff = damage_falloff
	new_projectile.ignoreCaster = ignoreSelf
	new_projectile.casterID = player_node.get_parent()
	new_projectile.add_collision_exception_with(get_parent())
	# Apply reticule position as projectile's starting position
	new_projectile.global_position = startpos
	# Apply force/velocity to the projectile to launch based on charge power and direction of aim
	new_projectile.linear_velocity = (startpos - position2) * speed * (attack_power * attack_scale)
	# Projectile is server so set variable
	new_projectile.server = isServer
	# Bring the configured projectile into the scene/world
	get_node("/root/environment").add_child(new_projectile)
