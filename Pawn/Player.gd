extends Node2D

### Root Player component. Most functions, movement, controls, etc are handled in MainPawn, but this node controls camera when not focused on player and set values for children

var control   = false
var player_id = 0
var root      = false
var console   = false
# Track current active pawn, for example teleport node, MainPawn node, or down the road minions
var currentActivePawn
onready var teleportingPawn = $MainPawn
# Tracks camera node
var camera


var mainPawnAttackList = ["Projectile"]


func _ready():
	# Don't show any GUI elements to the server
	if get_tree().is_network_server():
		$PlayerCamera.queue_free()
		$"MainPawn/VisionManager".queue_free()
		$"MainPawn/AttackManager".queue_free()
		if control:
			$MainPawn.control = control
			$MainPawn.player_id = player_id
	else:
		# Pass variables to children only if local player
		if control:
			currentActivePawn = $MainPawn
			$MainPawn.control = control
			$MainPawn.player_id = player_id
			$MainPawn.initiate_ui()
	
			# Set camera focus to player
			$PlayerCamera.control = control
			camera = $PlayerCamera
			camera.target = $MainPawn
			camera.root = self
			camera.playerOwner = $MainPawn
			camera.lastPlayerOwnerPosition = false
			camera.make_current()
			$TeleportManager.initialize()
			
		else:
			# remove UI for other players
			$"MainPawn/VisionManager".queue_free()
			$"MainPawn/AttackManager".queue_free()
			$PlayerCamera.get_node("CanvasLayer").get_node("GUI").queue_free()

func hideCamera():
	# Disable HUD
	if control:
		camera.get_node("CanvasLayer").get_node("GUI").visible = false

func showCamera():
	# Enable HUD
	if control:
		camera.get_node("CanvasLayer").get_node("GUI").visible = true

func switchFromPlayerCamera():
	# Reset current camera
	camera.lastPlayerOwnerPosition = false
	camera.position = Vector2.ZERO
	# Remove current camera
	camera.clear_current()
	# Set mouse location and view
	get_viewport().warp_mouse(get_viewport_rect().size / 2)

func switchToPlayerCamera():
	# Set mouse location and view
	get_viewport().warp_mouse(get_viewport_rect().size / 2)
	# Set new pawn camera
	camera.make_current()
	# Reset camera position
	camera.lastPlayerOwnerPosition = false
	camera.position = Vector2.ZERO
