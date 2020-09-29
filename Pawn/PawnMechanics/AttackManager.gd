extends Node

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
# Expose the actual HUD component's path
export var _reticule_anchor_node_path : NodePath
# Use the path to grab the base HUD component (the reticule's parent) as a var
onready var reticule_anchor : Node2D = get_node(_reticule_anchor_node_path)
# Track the actual Reticule component within the reticule parent as a var
var chargeProgress
# Static value for tracking the charge value before it fills the reticule
var reticule_max = 2

var skill_data

export var attackList = []
var currentSelectedAttack

# Called when the node enters the scene tree for the first time.
func _ready():
	chargeProgress = reticule_anchor.find_node("ChargeReticule")
	
	var file = File.new()
	if file.open("res://Skills/SkillData.json", file.READ) != OK:
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
		attackList = get_parent().get_parent().mainPawnAttackList # Replace with logic to pull from spell selection
	currentSelectedAttack = attackList[0]

func _process(delta):
	# Locally render the reticule every tick, optimize this to only be needed when attacking
	_render_reticule()

func _physics_process(_delta : float):
	# Execute only for local player
	if get_parent().get_parent().control:
		if !get_parent().has_node("StateManager") or (get_parent().has_node("StateManager") and get_parent().get_node("StateManager").allowActions):
			# Charge attack if holding charge button for shooting projectile
			if _attack_clicked:
				_attack_power += _delta
			
			# If the player has been holding the attack button long enough it auto fires
			if _attack_power >= _auto_attack_power:
				# Same standard typeless attack as line 120
				shoot(currentSelectedAttack)

func _input(event):
	if get_parent().get_parent().control:
		if !get_parent().has_node("StateManager") or (get_parent().has_node("StateManager") and get_parent().get_node("StateManager").allowActions):
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
		elif event is InputEventMouseButton and event.pressed and get_parent().get_parent().control:
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
	var reticule := reticule_anchor.find_node("Reticule")
	# Grab position of reticule as starting position of projectile
	var reticule_position = reticule.global_position

	# Summon projectile locally but have it just disappear on impact
	get_node("/root/").get_node("1").summonProjectile(reticule_position, get_parent().global_position, projectile_speed, _attack_power, _attack_scale, false, 0, 0, false, ignoreSelf, get_parent().get_parent().player_id, skill_type)
	# Broadcast RPC so projectile can be shown to other players/server
	get_node("/root/").get_node("1").rpc_id(1, "summonProjectileServer", reticule_position, get_parent().global_position, projectile_speed, _attack_power, _attack_scale, true, damage, explosion_radius, damage_falloff, ignoreSelf, get_parent().get_parent().player_id, skill_type)
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
	reticule_anchor.look_at(get_parent().get_global_mouse_position())
	# Change charge HUD display so it fills up as charging
	if _attack_clicked:
		chargeProgress.value = clamp(_attack_power + (1.05 * _auto_attack_power), (1.05 * _auto_attack_power), reticule_max)
