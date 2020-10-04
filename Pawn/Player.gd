extends Node2D

### Root Player component. Most functions, movement, controls, etc are handled in MainPawn, but this node controls camera when not focused on player and set values for children

var control   = false
var player_id = 0

export var map_path = "/root/environment/TestMap"
export var eventHandler_path = "/root/1"
onready var clientName = str(get_parent().name)

export var mainPawnAttackList = ["Projectile"]
# Track current active pawn, for example teleport node, MainPawn node, or down the road minions
var currentActivePawn
var pawnList = []
var minion_identifier = 0

func _ready():
	pawnList.append($MainPawn)
	currentActivePawn = $MainPawn
	# Gives the authority of the input manager to the player
	get_node("MainPawn/MovementInputManager").set_network_master(int(clientName))

func _input(event):
	if control and !$TeleportManager.teleporting:
		if event.is_action_pressed("test"):
			rpc_id(1, "switchPawnServer")
		elif event.is_action_pressed("test2"):
			rpc_id(1, "addMinionServer", "Minion")

func removePawnCallServer(pawn_id):
	if !get_tree().is_network_server():
		rpc_id(1, "removePawnServer", pawn_id)

remote func removePawnServer(pawn_id):
	removePawn(pawn_id)
	rpc("removePawnRPC", pawn_id)

remote func removePawnRPC(pawn_id):
	removePawn(pawn_id)

func removePawn(pawn_id):
	var erasePawn = get_node(pawn_id)
	if erasePawn == currentActivePawn:
		switchPawn()
	pawnList.erase(erasePawn)
	erasePawn.get_node("StateManager").freeze()
	erasePawn.get_node("StateManager").hide()
	erasePawn.terminate()

remote func switchPawnServer():
	switchPawn()
	rpc("switchPawnRPC")

remote func switchPawnRPC():
	switchPawn()

func switchPawn():
	var currentPawnpos = pawnList.find(currentActivePawn)
	var pawnListLastPos = pawnList.size()-1
	if pawnListLastPos > 0:
		if currentActivePawn.has_node("MovementInputManager"):
			currentActivePawn.get_node("MovementInputManager").movement.x = 0
		currentActivePawn.get_node("StateManager").reset()
		if currentActivePawn.has_node("AttackManager"):
			var attackManager = currentActivePawn.get_node("AttackManager")
			if attackManager._attack_power > 0:
				attackManager.shoot(attackManager.currentSelectedAttack)
	if currentPawnpos == -1:
		print("cannot find pawn")
		return
	if currentPawnpos == pawnListLastPos:
		currentActivePawn = pawnList[0]
	else:
		currentActivePawn = pawnList[currentPawnpos+1]
	if control:
		$PlayerCamera.changeTarget(currentActivePawn)
		# Reset the input of the old pawn

func switchToPawn(pawnName):
	var pawn = get_node(pawnName)
	var pawnPos = pawnList.find(pawn)
	if pawnPos == -1:
		print("cannot find pawn")
		return
	currentActivePawn = pawnList[pawnPos]

remote func addMinionServer(minion_id):
	rpc("addMinionRPC", minion_id)
	addMinion(minion_id)

remote func addMinionRPC(minion_id):
	addMinion(minion_id)

func addMinion(minion_id):
	var minion_dir = "res://Pawn/Minion/" + minion_id + ".tscn"
	var minion_scene = load(minion_dir)
	var minion = minion_scene.instance()
	minion.name += str(minion_identifier)
	add_child(minion)
	minion.get_node("MovementInputManager").set_network_master(int(clientName))
	pawnList.append(minion)
	# Testing minion control
	minion.position = Vector2($MainPawn.position.x, $MainPawn.position.y - $MainPawn.get_node("StateManager/Sprite").texture.get_size().y)
	minion.get_node("StateManager").reset()
	minion_identifier += 1
