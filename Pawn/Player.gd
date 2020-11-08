extends Node2D

##### Root Player component. Most functions, movement, controls, etc are handled in MovementManager, but this node controls camera when not focused on player and set values for children

### Network
# Tracks whether the player node is locally controlled or not
var control = false
# Tracks the network ID of the owning player as string
var clientName
# Tracks whether the node is a server that has P2P (also participating as a player)
var server_controlled = false

### Pawn Management
# Temporary variable for pulling in attacks from settings for main pawn
export var mainPawnAttackList = ["Projectile"]
# Array of all pawns that are being controlled by the player
var pawnList = []
# Track current active pawn, for example teleport node, MainPawn node, or down the road minions
var currentActivePawn
# Identifier int used to tack onto the minion and give it a unique name
var minion_identifier = 0
# Tracks whether the player is choosing where to place a minion
var selectMinion = false

### GUI Management
# Tracks whether a GUI menu is open or not
var menuPressed = false
# Tracks the GUI for ingame pawn
var player_gui
# Tracks the GUI for teleporting menu
var teleport_gui

### Map Management
# Tracks the path to the map, used by VisionManagers for now
var map_path = "/root/environment/TestMap"

# When node initializes
func initialize():
	# Adds the Main Pawn
	pawnList.append($MainPawn)
	currentActivePawn = $MainPawn
	
	# Sets player GUI, teleport GUI will be set by teleport manager
	player_gui = get_node("PlayerCamera/CanvasLayer/GUI")

	# Calls children's initialization nodes
	call_deferred("initialize_children")

# Initializes children nodes
func initialize_children():
	# Initializing Main Pawn
	$MainPawn.initialize()

	# Initializing Player Camera
	$PlayerCamera.initialize()

	# Initializing Teleport Manager
	$TeleportManager.initializePenaltyTimer()
	if (!get_tree().is_network_server() or (get_tree().is_network_server() and server_controlled)) and control:
		$TeleportManager.initialize()

# When input is pressed
func _input(event):
	
	# Temporary inputs on switching pawns
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

#################################GUI FUNCTIONS

# Toggles whether a menu is open or not
func menu(shouldOpen):
	if shouldOpen == true and !menuPressed:
		menuPress()
	elif shouldOpen == false:
		menuRelease()

# Actions taken when a menu is opened (actions are reset/stopped)
func menuPress():
	menuPressed = true
	if currentActivePawn.has_node("MovementInputManager"):
		currentActivePawn.get_node("MovementInputManager").movement.x = 0
	if currentActivePawn.has_node("AttackManager"):
		var attackManager = currentActivePawn.get_node("AttackManager")
		if attackManager._attack_power > 0:
			attackManager.shoot(attackManager.currentSelectedAttack)

# Actions taken when a menu is closed (actions resumed)
func menuRelease():
	menuPressed = false

# Swaps from player to teleport GUI mode
func switch_gui_to_teleport():
	player_gui.enabled = false
	teleport_gui.enabled = true

# Swaps from teleport to player GUI mode
func switch_gui_to_player():
	player_gui.enabled = true
	teleport_gui.enabled = false

#################################PAWN MANAGEMENT FUNCTIONS

# Handles adding a minion selection menu/GUI node to the player
func addMinionSelectLocation(size, minionSize, callingEntity, minionType):
	# Loads minion select scene
	var minion_select_loc_dir = "res://Pawn/Minion/MinionSelectLocation.tscn"
	var minion_select_loc_scene = load(minion_select_loc_dir)
	var minion_select_loc = minion_select_loc_scene.instance()
	# Sets variables to Minion Select scene
	minion_select_loc.name = "MinionSelect"
	minion_select_loc.minionType = minionType
	minion_select_loc.setSize(size, minionSize)
	# Initiates Minion Select scene
	callingEntity.add_child(minion_select_loc)
	minion_select_loc.initialize(self)
	
	# Resets attack if mid-attack
	if callingEntity.has_node("AttackManager"):
		callingEntity.get_node("AttackManager").resetAttack()
	
	# Toggles variable
	selectMinion = true

# Handles removing minion selection menu/GUI node if cancelled
func removeMinionSelectLocation(interrupt):
	# Searches if the node exists and removes
	var callingNode = find_node("MinionSelect", true, false)
	if callingNode:
		callingNode.queue_free()
	if interrupt:
		selectMinion = false

# Adds a pawn to the player for control
func addMinion(minion_id, pos):
	# Loads and adds pawn scene
	var minion_dir = "res://Pawn/Minion/" + minion_id + ".tscn"
	var minion_scene = load(minion_dir)
	var minion = minion_scene.instance()
	minion.name += str(minion_identifier)
	add_child(minion)
	# Set variables to pawn and add to pawnList
	pawnList.append(minion)
	minion.global_position = pos
	minion.get_node("StateManager").reset()
	minion_identifier += 1
	if control:
		selectMinion = false
	# Initialize minion
	minion.initialize()

# Switch control from current to next pawn in pawnList
func switchPawn():
	# Look for current pawn and throw error if it cannot
	var currentPawnpos = pawnList.find(currentActivePawn)
	if currentPawnpos == -1:
		print("cannot find pawn")
		return

	# Reset current pawn
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

	# Change position of current active pawn
	if currentPawnpos == pawnListLastPos:
		currentActivePawn = pawnList[0]
	else:
		currentActivePawn = pawnList[currentPawnpos+1]

	# Change camera to focus on new pawn
	if control:
		$PlayerCamera.changeTarget(currentActivePawn)

# Directly switch control to a certain pawn, may need to be worked on
func switchToPawn(pawnName):
	var pawn = get_node(pawnName)
	var pawnPos = pawnList.find(pawn)
	if pawnPos == -1:
		print("cannot find pawn")
		return
	currentActivePawn = pawnList[pawnPos]

# Handles removing a pawn from control and pawnList
func removePawn(pawn_id):
	# Find pawn to be erased
	var erasePawn = get_node(pawn_id)
	# Switch pawns if the one to be erased is the current controlled pawn
	if erasePawn == currentActivePawn:
		switchPawn()
	# Erase the pawn from the pawnList
	pawnList.erase(erasePawn)

	# Completely hide the pawn as it is pending deletion
	if erasePawn.has_node("HealthManager"):
		erasePawn.get_node("HealthManager").hideMiniHPBar()
	erasePawn.get_node("StateManager").freeze()
	erasePawn.get_node("StateManager").hide()
	# Set the pawn to be terminated
	erasePawn.terminate()

#################################PAWN MANAGEMENT RPC FUNCTIONS

# Wrapper RPC for server to switch pawns locally and call clients to switch pawns locally
func switchPawnAsServer():
	switchPawn()
	rpc("switchPawnRPC")

# Wrapper RPC for server called by client to switch pawns locally and call clients to switch pawns locally
remote func switchPawnServer():
	switchPawnAsServer()

# Wrapper RPC for client called from server to switch pawns locally
remote func switchPawnRPC():
	switchPawn()

# Wrapper RPC for client to call server to remove a pawn locally and call clients to remove a pawn locally
func removePawnCallServer(pawn_id):
	if !get_tree().is_network_server():
		rpc_id(1, "removePawnServer", pawn_id)

# Wrapper RPC for server to remove a pawn locally and call clients to remove a pawn locally
func removePawnAsServer(pawn_id):
	removePawn(pawn_id)
	rpc("removePawnRPC", pawn_id)

# Wrapper RPC for server called by client to remove a pawn locally and call clients to remove a pawn locally
remote func removePawnServer(pawn_id):
	removePawnAsServer(pawn_id)

# Wrapper RPC for client called by server to remove a pawn locally
remote func removePawnRPC(pawn_id):
	removePawn(pawn_id)

# Wrapper RPC for client to call server to add a pawn locally and call clients to add a pawn locally
func addMinionToServer(minion_id, pos):
	rpc_id(1, "addMinionServer", minion_id, pos)

# Wrapper RPC for server called by client to add a pawn locally and call clients to add a pawn locally
remote func addMinionServer(minion_id, pos):
	addMinionAsServer(minion_id, pos)

# Wrapper RPC for server to add a pawn locally and call clients to add a pawn locally
func addMinionAsServer(minion_id, pos):
	rpc("addMinionRPC", minion_id, pos)
	addMinion(minion_id, pos)

# Wrapper RPC for client called by server to add a pawn locally and call clients to add a pawn locally
remote func addMinionRPC(minion_id, pos):
	addMinion(minion_id, pos)
