extends KinematicBody2D

var snap = Vector2(0, 32)

var control = false
var pos = Vector2(2100, 1400)
export (Vector2) var _speed = Vector2(400, 600)
export (Vector2) var gravity = Vector2(0, 4800)
var _velocity : Vector2 = Vector2.ZERO

var JUMP_FORCE = 2000
var jump_direction = Vector2.ZERO
var player_id
var jumping

export var weapon_projectile : PackedScene
var _attack_power : float = 0
var _attack_scale : float = 3
var _attack_clicked : bool = false

export var _reticule_anchor_node_path : NodePath
onready var reticule_anchor : Node2D = get_node(_reticule_anchor_node_path)
# When _attack_power reaches this we'll force the shot. (ie, this is the max cap of power for any 1 shot)
onready var _auto_attack_power : float = 1
var reticule_max = 2
var chargeProgress

func _ready():
	self.position = pos

func _process(delta):
	if control:
		_render_reticule()

func _input(event):
	if control:
		if event.is_action_pressed("jump") and is_on_floor():
			snap = Vector2()
			jump_direction = Vector2(Input.get_action_strength("right") - Input.get_action_strength("left"), 0)
			_velocity.y += -JUMP_FORCE
			jumping = true

		if event.is_action_released("jump") and jumping and _velocity.y <= -500:
			_velocity.y = -500

		if event.is_action_pressed("shoot"):
				_attack_clicked = true
				chargeProgress = reticule_anchor.find_node("chargeReticule")
				chargeProgress.max_value = reticule_max
				chargeProgress.visible = true
		elif event.is_action_released("shoot"):
			# We're checking _attack_clicked because it gets set to false if
			# we auto-fire because the player held the button for too long.
			if _attack_clicked:
				shoot()
			_attack_clicked = false
			chargeProgress.visible = false
			chargeProgress.value = 0

func _physics_process(_delta : float):
	
	if control:
		
		if _attack_clicked:
			_attack_power += _delta
		
		# If the player has been holding the attack button for too long, we'll shoot for them.5
		if _attack_power >= _auto_attack_power:
			shoot()
		
		if _velocity.y >= 0 and !is_on_floor():
			snap = Vector2(0, 32)
			
		# Probably can do this not every tick but poll for correction of location every x time
		movePlayer()

	# Animation stuff
	if _velocity.x >= 1:
		$Sprite.flip_h = false
	elif _velocity.x <= -1:
		$Sprite.flip_h = true


func movePlayer():
	var input_direction = _get_input_direction()
	
	_velocity = _calculate_move_velocity(_velocity, input_direction, _speed)
	#_velocity = move_and_slide(_velocity, Vector2(0, -1))
	_velocity = move_and_slide_with_snap(_velocity, snap, Vector2.UP, true, 4, deg2rad(90.0))
	rpc_unreliable("updateRPCposition", position, player_id)

	if jumping and is_on_floor():
		jumping = false
		jump_direction = Vector2.ZERO

func shoot():
	# Spawn projectile
	var reticule := reticule_anchor.find_node("Reticule")
	var reticule_position = reticule.global_position

	var new_projectile := weapon_projectile.instance() as RigidBody2D
	new_projectile.global_position = reticule_position
	new_projectile.linear_velocity = (reticule_position - global_position) * 30 * (_attack_power * _attack_scale)
	get_parent().add_child(new_projectile)

	rpc("summonProjectileRPC", reticule_position, global_position, 30, _attack_power, _attack_scale)
	
	# Reset the power-improvement meter
	_attack_power = 0
	_attack_clicked = false
	chargeProgress.visible = false
	chargeProgress.value = 0

#################################SERVER FUNCTIONS

remote func updateRPCposition(pos, pid):
	var root  = get_parent().get_parent()
	var pnode = root.get_node(str(pid)).find_node("playerPhysicsBody")
	
	pnode.position = pos

remote func summonProjectileRPC(startpos, position2, speed, attack_power, attack_scale):
	var new_projectile := weapon_projectile.instance() as RigidBody2D
	new_projectile.global_position = startpos
	new_projectile.linear_velocity = (startpos - position2) * speed * (attack_power * attack_scale)
	get_parent().add_child(new_projectile)

#################################HELPER FUNCTIONS

func _get_input_direction() -> Vector2:
	if is_on_floor():
		return Vector2(Input.get_action_strength("right") - Input.get_action_strength("left"), 0)
	elif jumping:
		return jump_direction
	else:
		return Vector2(0,0)

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
	reticule_anchor.look_at(get_global_mouse_position())
	if _attack_clicked:
		chargeProgress.value = clamp(_attack_power + (1.05 * _auto_attack_power), (1.05 * _auto_attack_power), reticule_max)
