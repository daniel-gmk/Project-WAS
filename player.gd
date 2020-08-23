extends Node2D

var control   = false
var player_id = 0
var root      = false
var console   = false
var tree      = {}
onready var playerPhysicsBody = $playerPhysicsBody

func _ready():
	# set camera
	if control:
		$playerPhysicsBody.control = control
		$playerPhysicsBody.player_id = player_id
		$PlayerCamera.control = control

		var camera = $PlayerCamera
		camera.root = self
		camera.playerOwner = $playerPhysicsBody
		camera.make_current()
		camera.changeToPlayerOwner()
	
	root    = get_parent()
	set_process(true)

#func _process(delta):
	#if control == true:
	#	if console && console.shown:
	#		pass
		#else:
			# this is where moving was
		#	_get_input()
