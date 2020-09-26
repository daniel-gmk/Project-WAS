extends Node

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

# Called when the node enters the scene tree for the first time.
func _ready():
	chargeProgress = reticule_anchor.find_node("ChargeReticule")

func _process(delta):
	# Locally render the reticule every tick, optimize this to only be needed when attacking
	_render_reticule()

func _physics_process(_delta : float):
	# Execute only for local player
	if get_parent().control and get_parent().allowActions:
		
		# Charge attack if holding charge button for shooting projectile
		if _attack_clicked:
			_attack_power += _delta
		
		# If the player has been holding the attack button long enough it auto fires
		if _attack_power >= _auto_attack_power:
			# Same standard typeless attack as line 120
			shoot(500, 42, true, false)

func _input(event):
	if get_parent().control and get_parent().allowActions:
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

# Handles attacking, for now using a base projectile
func shoot(damage, explosion_radius, damage_falloff, ignoreSelf):
	## This is local execution of projectile
	# Get reticule to find position of reticule
	var reticule := reticule_anchor.find_node("Reticule")
	# Grab position of reticule as starting position of projectile
	var reticule_position = reticule.global_position

	# Summon projectile locally but have it just disappear on impact
	get_node("/root/").get_node("1").summonProjectile(reticule_position, get_parent().global_position, 30, _attack_power, _attack_scale, false, 0, 0, false, ignoreSelf, get_parent().player_id)
	# Broadcast RPC so projectile can be shown to other players/server
	get_node("/root/").get_node("1").rpc_id(1, "summonProjectileServer", reticule_position, get_parent().global_position, 30, _attack_power, _attack_scale, true, damage, explosion_radius, damage_falloff, ignoreSelf, get_parent().player_id)
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
