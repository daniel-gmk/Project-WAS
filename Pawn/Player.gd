extends Node2D

### Root Player component. Most functions, movement, controls, etc are handled in MainPawn, but this node controls camera when not focused on player and set values for children

var control   = false
var player_id = 0
# Track current active pawn, for example teleport node, MainPawn node, or down the road minions
var currentActivePawn
onready var teleportingPawn = $MainPawn
export var map_path = "/root/environment/TestMap"
export var eventHandler_path = "/root/1"
onready var clientName = str(get_parent().name)

export var mainPawnAttackList = ["Projectile"]

func _ready():
	# Don't show any GUI elements to the server
	if !get_tree().is_network_server():
		# Pass variables to children only if local player
		if control:
			currentActivePawn = $MainPawn
