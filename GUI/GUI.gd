extends Control

##### This node handles ingame GUI that the player uses

### Main Variables, variables handled by the root GUI
# Tracks whether GUI is enabled, can pause processing/actions
export var enabled = true
# Tracks player node that owns this GUI
var player_node
# Tracks whether the node is locally owned
var local = false
# Tracks camera node that owns this GUI
var camera_node
# Tracks whether the node is initialized
var initialized = false

### Teleport
# Whether the GUI is for teleporting or for ingame use, there are two modes the GUI uses
export var teleportMode = false
# Path to teleport cooldown icon
export var teleport_cooldown_nodepath : NodePath
# Node for teleport cooldown
var teleport_cooldown
# Path to teleport action (time until health penalty, health penalty amount, etc)
export var teleport_nodepath : NodePath
# Node for teleport action
var teleport

### Minimap
# Path to minimap
export var minimap_gui_nodepath : NodePath
# Node for minimap node in gui
var minimap_gui_node
# Node for minimap sprite moved from root
var minimap_node
# Tracks size of minimap
var minimapSize
# Tracks camera overlay (yellow box) that represents camera size and camera view in minimap
var minimapCamera

### Chat
# Path to ingame chat
export var chat_nodepath : NodePath
# Node holding chat
var chatOuter
var chatInner
var savedMessages
var sentMessages
# Tracks whether chat is open
var chatOpen = false
# How long chat text lasts before fading out
var chatTextExpire = 5.0
# Different text flag options
var textFlagOptions = ["[All]", "[Team]", "[Whisper]"]
# Different Text Flag colors, might merge with textFlagOptions as dict, must match
var textFlagColors = ["[color=white]", "[color=#3399ff]", "[color=#ff66ff]"]
# Tracks which text Flag is selected
var textFlagPlacement = 0

### Health Bar
# Path to health bar
export var healthbar_nodepath : NodePath
# Node for health bar
var healthbar

### Escape Menu
var escOpen = false

# Called when the node enters the scene tree for the first time.
func initialize(playerNode):
	# Set initial nodes and variables
	player_node = playerNode
	teleport_cooldown = get_node(teleport_cooldown_nodepath)
	healthbar = get_node(healthbar_nodepath)
	chatOuter = get_node(chat_nodepath)
	chatInner = chatOuter.get_node("HBoxContainer/VBoxContainer")
	savedMessages = chatInner.get_node("MarginContainer/SavedMessages")
	sentMessages = chatInner.get_node("MarginContainer/SentMessages")
	chatInner.get_node("SendingMessage/TextFlag").bbcode_text = textFlagOptions[textFlagPlacement]
	
	if player_node.control:
		local = true
	
	# Initiate if teleport mode
	if teleportMode:
		# Turn minimap and healthbar off
		get_node(minimap_gui_nodepath).visible = false
		healthbar.visible = false
		# Turn teleport module on
		teleport = get_node(teleport_nodepath)
		teleport.get_node("TextureProgress").max_value = player_node.get_node("TeleportManager").teleportSelectPenaltyTime
		teleport.visible = true
		
		# Copy chat from ingame GUI
		for getgui in get_tree().get_nodes_in_group("GUI"):
			if getgui.teleportMode != teleportMode:
				var exit = false
				if getgui.savedMessages.bbcode_text != "":
					savedMessages.bbcode_text = getgui.savedMessages.bbcode_text
					exit = true
				if getgui.sentMessages.bbcode_text != "":
					sentMessages.bbcode_text = getgui.sentMessages.bbcode_text
					exit = true
				if exit:
					break

	else:
	# Initiate when not teleport mode
		if local:

			# Set ingame teleport cooldown icon
			teleport_cooldown.max_value = player_node.get_node("TeleportManager").teleportCooldown
			teleport_cooldown.value = player_node.get_node("TeleportManager").teleportCooldown
			
			# Loads local minimap
			var testMap = get_node("/root/environment/TestMap")
			minimap_gui_node = get_node(minimap_gui_nodepath)
			minimap_node = testMap.minimapNode
			minimapSize = testMap.minimapRatio
			minimap_node.get_parent().remove_child(minimap_node)
			minimap_gui_node.add_child(minimap_node)
			minimap_node.set_owner(minimap_gui_node)
			minimap_node.z_index = 1
			minimapCamera = minimap_gui_node.get_node("CameraIndicator")
			add_to_group("localGUI")
	
	# Add GUI group so both teleport and non teleport GUI are together
	add_to_group("GUI")
	# Set Initialized
	initialized = true

# When input occurs
func _input(event):
	if initialized and enabled:
		# When chat button is pressed (toggle)
		if event.is_action_pressed("Chat"):
			if !escOpen:
				if !player_node.menuPressed:
					openChat()
					player_node.menu(true)
				else:
					sendMessageLocal()
					closeChat()
					player_node.menu(false)
		# When esc button is pressed (toggle)
		elif event.is_action_pressed("EscMenu"):
			if !escOpen:
				if !player_node.menuPressed:
					player_node.menu(true)
				closeOtherMenus()
				openEsc()
			else:
				player_node.menu(false)
				closeEsc()
		# When tab button is pressed (scoreboard or chat)
		elif event.is_action_pressed("Scoreboard") and chatOpen:
			rotateTextFlagPlacement()

# Helper function to close all other menus as priority
func closeOtherMenus():
	if chatOpen:
		closeChat()

# Open escape menu
func openEsc():
	escOpen = true

# Close escape menu
func closeEsc():
	escOpen = false

# Open chat
func openChat():
	# Unhide chat menu
	chatOuter.self_modulate = Color(0,0,0,.24)
	chatOuter.set_mouse_filter(0)
	
	# Unhide certain chat components and allow mouse
	chatInner.get_node("MarginContainer").set_mouse_filter(0)
	chatInner.get_node("ColorRect").visible = true
	
	# Unhide and auto focus on chat bar (send messages)
	var sendingMessage = chatInner.get_node("SendingMessage")
	sendingMessage.visible = true
	sendingMessage.get_node("LineEdit").set_mouse_filter(0)
	sendingMessage.get_node("LineEdit").call_deferred("grab_focus")
	
	# Unhide permanent chatlog
	savedMessages.set_mouse_filter(0)
	savedMessages.visible = true
	
	# Hide temporary chatlog (fade out expiry chat)
	sentMessages.set_mouse_filter(0)
	sentMessages.visible = false

	# Set chat as open
	chatOpen = true

func closeChat():
	# Hide chat menu
	chatOuter.self_modulate = Color(0,0,0,0)
	chatOuter.set_mouse_filter(2)

	# Show certain chat components and disallow mouse
	chatInner.get_node("MarginContainer").set_mouse_filter(2)
	chatInner.get_node("ColorRect").visible = false

	# Hide chat bar (send messages)
	var sendingMessage = chatInner.get_node("SendingMessage")
	sendingMessage.visible = false
	sendingMessage.get_node("LineEdit").set_mouse_filter(2)
	
	# Hide permanent chatlog
	savedMessages.set_mouse_filter(2)
	savedMessages.visible = false
	
	# Show temporary chatlog (fade out expiry chat)
	sentMessages.set_mouse_filter(2)
	sentMessages.visible = true

	# Set chat as closed
	chatOpen = false

# Accepting a message to be sent from player's chat bar
func sendMessageLocal():
	var sendingMessage = chatInner.get_node("SendingMessage")
	if sendingMessage.get_node("LineEdit").text != "":
		# Set variables and clear chat bar
		var lineEdit = sendingMessage.get_node("LineEdit")
		var message = lineEdit.text
		lineEdit.text = ""

		# Send message locally
		for gui_node_in_group in get_tree().get_nodes_in_group("GUI"):
			gui_node_in_group.sendMessage(message, player_node.clientName, textFlagPlacement, false)

		# Send the message over RPC
		if get_tree().is_network_server():
			if player_node.server_controlled:
				get_node("/root/1/MessageHandler").sendMessageAsServer(message, player_node.clientName, textFlagPlacement, false)
		else:
			get_node("/root/1/MessageHandler").sendMessageToServer(message, player_node.clientName, textFlagPlacement, false)

# Sending a message in chat
func sendMessage(message, playerClient, flagPlacement, systemMessage):
	
	# Get timestamp to append to beginning of message
	var time = OS.get_time()
	var timemin
	if time.minute < 10:
		timemin = "0" + str(time.minute)
	else:
		timemin = str(time.minute)
		
	# Assemble message
	var prefix
	if systemMessage:
		prefix = "[" + str(time.hour) + ":" + timemin + "] " + "SYSTEM" + ": "
		savedMessages.bbcode_text += "[color=yellow]" + prefix + message + "[/color]" + "\n"
		sentMessages.bbcode_text += "[ghost time=" + str(OS.get_ticks_msec()) + "]" + "[color=yellow]" + prefix + message + "[/color]" + "[/ghost]" + "\n"
	else:
		prefix = "[" + str(time.hour) + ":" + timemin + "] " + playerClient + ": "
		savedMessages.bbcode_text += "[url=" + playerClient + "]" + textFlagColors[flagPlacement] + textFlagOptions[flagPlacement] + prefix + message + "[/color]" + "[/url]" + "\n"
		sentMessages.bbcode_text += "[url=" + playerClient + "]" + "[ghost time=" + str(OS.get_ticks_msec()) + "]" + textFlagColors[flagPlacement] + textFlagOptions[flagPlacement] + prefix + message + "[/color]" + "[/ghost]" + "[/url]" + "\n"

# Change between message modes
func rotateTextFlagPlacement():
	textFlagPlacement += 1
	if textFlagPlacement == textFlagOptions.size():
		textFlagPlacement = 0
	sentMessages.get_node("TextFlag").bbcode_text = textFlagColors[textFlagPlacement] + textFlagOptions[textFlagPlacement] + "[/color]"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if initialized and local and enabled:
		
		# Show teleport cooldown
		teleport_cooldown.value = player_node.get_node("TeleportManager").teleportCooldownTimer.get_time_left()

		if teleportMode:
			
			# Render radial progress bar with teleport time before damage penalty
			teleport.get_node("Label").text = str(stepify(player_node.get_node("TeleportManager").teleportSelectPenaltyTimer.get_time_left(), 0.1))
			teleport.get_node("TextureProgress").value = player_node.get_node("TeleportManager").teleportSelectPenaltyTimer.get_time_left()
			teleport.get_node("DamageLabel").text = "-" + str(player_node.get_node("TeleportManager").accumulatedTeleportDamage) + "HP"
		else:
			
			# Render minimap if not teleport mode

			# Set variables for local player's pawns
			var self_owned_entity_list = player_node.pawnList
			# Get size of local player's main pawn
			var mainPawnSize = player_node.get_node("MainPawn/BodyCollision").shape.height

			# Purge pawn minimap indicators that do not exist anymore
			for minion_indicator in get_tree().get_nodes_in_group("MinionIndicators"):
				if self_owned_entity_list.find(minion_indicator.linkedPawn) == -1:
					minion_indicator.queue_free()

			# Set camera overlay (yellow box) that represents camera size and camera view in minimap
			var global_camera = (get_viewport().get_visible_rect().size * camera_node.zoom)
			minimapCamera.scale = Vector2((global_camera.x / minimapSize) / minimapCamera.texture.get_width(), (global_camera.y / minimapSize) / minimapCamera.texture.get_height())
			minimapCamera.position = camera_node.position / minimapSize
			
			# Set selected pawn indicator (blue triangle) that indicates the pawn that is being controlled
			var currentPawn = player_node.currentActivePawn
			minimap_gui_node.get_node("SelectedPawnIndicator").position = Vector2(currentPawn.position.x / minimapSize, (currentPawn.position.y - (currentPawn.get_node("BodyCollision").shape.height) * 13) / minimapSize)
			minimap_gui_node.get_node("SelectedPawnIndicator").visible = currentPawn.get_node("StateManager/Sprite").visible

			# Parse through each pawn
			for pawn in self_owned_entity_list:
				# Update MainPawn indicator
				if pawn.name == "MainPawn":
					minimap_gui_node.get_node("MainPawnIndicator").position = (pawn.position / minimapSize)
					minimap_gui_node.get_node("MainPawnIndicator").visible = pawn.get_node("StateManager/Sprite").visible
				else:
					# Create a new pawn indicator for ones that do not exist in minimap
					if !minimap_gui_node.has_node(pawn.name + "Indicator"):
						var minion_indicator = Sprite.new()
						minion_indicator.name = pawn.name + "Indicator"
						minion_indicator.texture = load("res://assets/minimap-minion-indicator.png")
						minion_indicator.z_index = 3
						minion_indicator.set_script(load("res://GUI/Indicator.gd"))
						var scaleVal = (pawn.get_node("BodyCollision").shape.height/mainPawnSize) / 4
						minion_indicator.linkedPawn = pawn
						minion_indicator.scale = Vector2(scaleVal, scaleVal)
						minimap_gui_node.add_child(minion_indicator)
						minion_indicator.add_to_group("MinionIndicators")
					# Update position of pawn indicators
					minimap_gui_node.get_node(pawn.name + "Indicator").position = (pawn.position / minimapSize)
					minimap_gui_node.get_node(pawn.name + "Indicator").visible = pawn.get_node("StateManager/Sprite").visible

			# Parse through each enemy pawn in vision
			var enemy_list = get_tree().get_nodes_in_group("OnScreenEntities")
			if enemy_list.size() > 0:
				for enemy in enemy_list:
					var enemy_indicator_name = enemy.player_node.clientName + enemy.name + "Indicator"

					# Remove all enemies that are not in camera view
					if !enemy.get_node("VisibilityNotifier").inView:
						if minimap_gui_node.has_node(enemy_indicator_name):
							minimap_gui_node.get_node(enemy_indicator_name).queue_free()
						continue

					# Remove all enemies that are not in VisionManager range (if applicable)
					if player_node.currentActivePawn.has_node("VisionManager") and player_node.currentActivePawn.get_node("VisionManager").underground:
						var vision_overlap_list = player_node.currentActivePawn.get_node("VisionManager").overlapping_nodes
						if vision_overlap_list.find(enemy) == -1:
							if minimap_gui_node.has_node(enemy_indicator_name):
								minimap_gui_node.get_node(enemy_indicator_name).queue_free()
							continue

					# Create new enemy minimap indicator if it does not already exist
					if !minimap_gui_node.has_node(enemy_indicator_name):
						var enemy_indicator = Sprite.new()
						enemy_indicator.name = enemy_indicator_name
						enemy_indicator.texture = load("res://assets/minimap-enemy-indicator.png")
						enemy_indicator.z_index = 5
						var scaleVal = (enemy.get_node("BodyCollision").shape.height/mainPawnSize) / 4
						enemy_indicator.scale = Vector2(scaleVal, scaleVal)
						minimap_gui_node.add_child(enemy_indicator)
					
					# Set enemy minimap indicator position
					minimap_gui_node.get_node(enemy_indicator_name).position = (enemy.position / minimapSize)
					minimap_gui_node.get_node(enemy_indicator_name).visible = enemy.get_node("StateManager/Sprite").visible
