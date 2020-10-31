extends Node2D

### Root Player component. Most functions, movement, controls, etc are handled in MainPawn, but this node controls camera when not focused on player and set values for children

var control   = false
var player_id = 0
var server_controlled = false

export var map_path = "/root/environment/TestMap"
export var eventHandler_path = "/root/1"
onready var clientName = str(get_parent().name)

export var mainPawnAttackList = ["Projectile"]
# Track current active pawn, for example teleport node, MainPawn node, or down the road minions
var currentActivePawn
var pawnList = []
var minion_identifier = 0
var menuPressed = false
var selectMinion = false
var player_gui
var teleport_gui

func _ready():
	player_gui = get_node("PlayerCamera/CanvasLayer/GUI")
	pawnList.append($MainPawn)
	currentActivePawn = $MainPawn
	# Gives the authority of the input manager to the player
	get_node("MainPawn/MovementInputManager").set_network_master(int(clientName))

func _input(event):
	if control and !menuPressed and !$TeleportManager.teleporting:
		if event.is_action_pressed("test"):
			if selectMinion:
				removeMinionSelectLocation(true)
			
			if get_tree().is_network_server():
				if server_controlled:
					switchPawnAsServer()
			else:
				rpc_id(1, "switchPawnServer")
		elif event.is_action_pressed("test2"):
			if !selectMinion:
				addMinionSelectLocation(300, get_node("MainPawn/BodyCollision").shape.height, $MainPawn, "Minion")
			else:
				removeMinionSelectLocation(true)

func switch_gui_to_teleport():
	player_gui.enabled = false
	teleport_gui.enabled = true

func switch_gui_to_player():
	player_gui.enabled = true
	teleport_gui.enabled = false

func menu(shouldOpen):
	if shouldOpen == true and !menuPressed:
		menuPress()
	elif shouldOpen == false:
		menuRelease()

func menuPress():
	menuPressed = true
	if currentActivePawn.has_node("MovementInputManager"):
		currentActivePawn.get_node("MovementInputManager").movement.x = 0
	if currentActivePawn.has_node("AttackManager"):
		var attackManager = currentActivePawn.get_node("AttackManager")
		if attackManager._attack_power > 0:
			attackManager.shoot(attackManager.currentSelectedAttack)

func menuRelease():
	menuPressed = false

func addMinionSelectLocation(size, minionSize, callingEntity, minionType):
	var minion_select_loc_dir = "res://Pawn/Minion/MinionSelectLocation.tscn"
	var minion_select_loc_scene = load(minion_select_loc_dir)
	var minion_select_loc = minion_select_loc_scene.instance()
	minion_select_loc.name = "MinionSelect"
	minion_select_loc.minionType = minionType
	minion_select_loc.setSize(size, minionSize)
	callingEntity.add_child(minion_select_loc)
	
	if callingEntity.has_node("AttackManager"):
		callingEntity.get_node("AttackManager").resetAttack()
	
	selectMinion = true

func removeMinionSelectLocation(interrupt):
	var callingNode = find_node("MinionSelect", true, false)
	if callingNode:
		callingNode.queue_free()
	if interrupt:
		selectMinion = false

func removePawnCallServer(pawn_id):
	if !get_tree().is_network_server():
		rpc_id(1, "removePawnServer", pawn_id)

func removePawnAsServer(pawn_id):
	removePawn(pawn_id)
	rpc("removePawnRPC", pawn_id)

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
	if erasePawn.has_node("HealthManager"):
		erasePawn.get_node("HealthManager").hideMiniHPBar()
	erasePawn.get_node("StateManager").freeze()
	erasePawn.get_node("StateManager").hide()
	erasePawn.terminate()

func switchPawnAsServer():
	switchPawn()
	rpc("switchPawnRPC")

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
		currentActivePawn.get_node("StateManager").allowActions = true
		currentActivePawn.allowMovement = true
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

func addMinionToServer(minion_id, pos):
	rpc_id(1, "addMinionServer", minion_id, pos)

func addMinionAsServer(minion_id, pos):
	rpc("addMinionRPC", minion_id, pos)
	addMinion(minion_id, pos)

remote func addMinionServer(minion_id, pos):
	rpc("addMinionRPC", minion_id, pos)
	addMinion(minion_id, pos)

remote func addMinionRPC(minion_id, pos):
	addMinion(minion_id, pos)

func addMinion(minion_id, pos):
	var minion_dir = "res://Pawn/Minion/" + minion_id + ".tscn"
	var minion_scene = load(minion_dir)
	var minion = minion_scene.instance()
	minion.name += str(minion_identifier)
	add_child(minion)
	minion.get_node("MovementInputManager").set_network_master(int(clientName))
	pawnList.append(minion)
	# Testing minion control
	minion.global_position = pos
	minion.get_node("StateManager").reset()
	minion_identifier += 1
	if control:
		selectMinion = false
