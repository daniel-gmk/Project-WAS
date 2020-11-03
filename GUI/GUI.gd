extends Control


# Declare member variables here. Examples:
# var a = 2
export var minimap_gui_nodepath : NodePath
export var teleport_cooldown_nodepath : NodePath
export var chat_nodepath : NodePath
export var teleport_nodepath : NodePath
export var healthbar_nodepath : NodePath

export var enabled = true
export var teleportMode = false

var chat
var teleport
var teleport_cooldown
var healthbar
var minimap_gui_node
var minimap_node
var minimapSize
var minimapCamera
var player_node
var local = false
var indicatorScript
var chatOpen = false
var escOpen = false
var chatTextExpire = 5.0
var textFlagOptions = ["[All]", "[Team]", "[Whisper]"]
var textFlagColors = ["[color=white]", "[color=#3399ff]", "[color=#ff66ff]"]
var textFlagPlacement = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	if teleportMode:
		player_node = get_parent().get_parent().get_parent().get_parent()
	else:
		player_node = get_parent().get_parent().get_parent()
	teleport_cooldown = get_node(teleport_cooldown_nodepath)
	chat = get_node(chat_nodepath)
	healthbar = get_node(healthbar_nodepath)
	chat.get_node("HBoxContainer/VBoxContainer/SendingMessage/TextFlag").bbcode_text = textFlagOptions[textFlagPlacement]
	if teleportMode:
		teleport = get_node(teleport_nodepath)
		teleport.get_node("TextureProgress").max_value = player_node.get_node("TeleportManager").teleportSelectPenaltyTime
		teleport.visible = true
		get_node(minimap_gui_nodepath).visible = false
		healthbar.visible = false
		for getgui in get_tree().get_nodes_in_group("GUI"):
			var exit = false
			if getgui.chat.get_node("HBoxContainer/VBoxContainer/MarginContainer/SavedMessages").bbcode_text != "":
				chat.get_node("HBoxContainer/VBoxContainer/MarginContainer/SavedMessages").bbcode_text = getgui.chat.get_node("HBoxContainer/VBoxContainer/MarginContainer/SavedMessages").bbcode_text
				exit = true
			if getgui.chat.get_node("HBoxContainer/VBoxContainer/MarginContainer/SentMessages").bbcode_text != "":
				chat.get_node("HBoxContainer/VBoxContainer/MarginContainer/SentMessages").bbcode_text = getgui.chat.get_node("HBoxContainer/VBoxContainer/MarginContainer/SentMessages").bbcode_text
				exit = true
			if exit:
				break
		if (!get_tree().is_network_server() or (get_tree().is_network_server() and player_node.server_controlled)) and int(player_node.get_parent().name) == get_tree().get_network_unique_id():
			local = true
	else:
		indicatorScript = preload("res://GUI/Indicator.gd")
		if (!get_tree().is_network_server() or (get_tree().is_network_server() and player_node.server_controlled)) and int(player_node.get_parent().name) == get_tree().get_network_unique_id():
			local = true
			
			teleport_cooldown.max_value = player_node.get_node("TeleportManager").teleportCooldown
			teleport_cooldown.value = player_node.get_node("TeleportManager").teleportCooldown
			
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
	add_to_group("GUI")

func _input(event):
	if enabled:
		# Handle charging projectile strength when shoot input is pressed and held
		if event.is_action_pressed("Chat"):
			if !escOpen:
				if !player_node.menuPressed:
					openChat()
					player_node.menu(true)
				else:
					sendMessageLocal()
					closeChat()
					player_node.menu(false)

		elif event.is_action_pressed("EscMenu"):
			if !escOpen:
				if !player_node.menuPressed:
					player_node.menu(true)
				closeOtherMenus()
				openEsc()
			else:
				player_node.menu(false)
				closeEsc()
		
		elif event.is_action_pressed("tab") and chatOpen:
			rotateTextFlagPlacement()

func closeOtherMenus():
	if chatOpen:
		closeChat()

func openChat():
	chat.self_modulate = Color(1, 1, 1, 1)
	chat.get_node("HBoxContainer/VBoxContainer/SendingMessage").visible = true
	chat.get_node("HBoxContainer/VBoxContainer/SendingMessage/LineEdit").set_mouse_filter(0)
	chat.get_node("HBoxContainer/VBoxContainer/MarginContainer").set_mouse_filter(0)
	chat.get_node("HBoxContainer/VBoxContainer/MarginContainer/SavedMessages").set_mouse_filter(0)
	chat.get_node("HBoxContainer/VBoxContainer/MarginContainer/SentMessages").set_mouse_filter(0)
	chat.get_node("HBoxContainer/VBoxContainer/MarginContainer/SavedMessages").visible = true
	chat.get_node("HBoxContainer/VBoxContainer/MarginContainer/SentMessages").visible = false
	chat.get_node("HBoxContainer/VBoxContainer/ColorRect").visible = true
	chat.self_modulate = Color(0,0,0,.24)
	chat.set_mouse_filter(0)
	chat.get_node("HBoxContainer/VBoxContainer/SendingMessage/LineEdit").call_deferred("grab_focus")
	chatOpen = true
	# Enable mouse events

func closeChat():
	# Send whatever is currently in chat to everyone else and empty the current chat
	chat.self_modulate = Color(1, 1, 1, 0)
	chat.get_node("HBoxContainer/VBoxContainer/SendingMessage").visible = false
	chat.get_node("HBoxContainer/VBoxContainer/SendingMessage/LineEdit").set_mouse_filter(2)
	chat.get_node("HBoxContainer/VBoxContainer/MarginContainer").set_mouse_filter(2)
	chat.get_node("HBoxContainer/VBoxContainer/MarginContainer/SavedMessages").set_mouse_filter(2)
	chat.get_node("HBoxContainer/VBoxContainer/MarginContainer/SentMessages").set_mouse_filter(2)
	chat.get_node("HBoxContainer/VBoxContainer/MarginContainer/SavedMessages").visible = false
	chat.get_node("HBoxContainer/VBoxContainer/MarginContainer/SentMessages").visible = true
	chat.get_node("HBoxContainer/VBoxContainer/ColorRect").visible = false
	chat.self_modulate = Color(0,0,0,0)
	chat.set_mouse_filter(2)
	chatOpen = false
	# Disable mouse events

func sendMessageLocal():
	if chat.get_node("HBoxContainer/VBoxContainer/SendingMessage/LineEdit").text != "":
		var lineEdit = chat.get_node("HBoxContainer/VBoxContainer/SendingMessage/LineEdit")
		var message = lineEdit.text
		lineEdit.text = ""
		for gui_node_in_group in get_tree().get_nodes_in_group("GUI"):
			gui_node_in_group.sendMessage(message, player_node.clientName, textFlagPlacement, false)

		if get_tree().is_network_server():
			if player_node.server_controlled:
				get_node("/root/1/MessageHandler").sendMessageAsServer(message, player_node.clientName, textFlagPlacement, false)
		else:
			get_node("/root/1/MessageHandler").sendMessageToServer(message, player_node.clientName, textFlagPlacement, false)

func sendMessage(message, playerClient, flagPlacement, systemMessage):
	var time = OS.get_time()
	var timemin
	if time.minute < 10:
		timemin = "0" + str(time.minute)
	else:
		timemin = str(time.minute)
	var prefix
	if systemMessage:
		prefix = "[" + str(time.hour) + ":" + timemin + "] " + "SYSTEM" + ": "
		chat.get_node("HBoxContainer/VBoxContainer/MarginContainer/SavedMessages").bbcode_text += "[color=yellow]" + prefix + message + "[/color]" + "\n"
		chat.get_node("HBoxContainer/VBoxContainer/MarginContainer/SentMessages").bbcode_text += "[ghost time=" + str(OS.get_ticks_msec()) + "]" + "[color=yellow]" + prefix + message + "[/color]" + "[/ghost]" + "\n"
	else:
		prefix = "[" + str(time.hour) + ":" + timemin + "] " + playerClient + ": "
		chat.get_node("HBoxContainer/VBoxContainer/MarginContainer/SavedMessages").bbcode_text += "[url=" + playerClient + "]" + textFlagColors[flagPlacement] + textFlagOptions[flagPlacement] + prefix + message + "[/color]" + "[/url]" + "\n"
		chat.get_node("HBoxContainer/VBoxContainer/MarginContainer/SentMessages").bbcode_text += "[url=" + playerClient + "]" + "[ghost time=" + str(OS.get_ticks_msec()) + "]" + textFlagColors[flagPlacement] + textFlagOptions[flagPlacement] + prefix + message + "[/color]" + "[/ghost]" + "[/url]" + "\n"

func rotateTextFlagPlacement():
	textFlagPlacement += 1
	if textFlagPlacement == textFlagOptions.size():
		textFlagPlacement = 0
	chat.get_node("HBoxContainer/VBoxContainer/SendingMessage/TextFlag").bbcode_text = textFlagColors[textFlagPlacement] + textFlagOptions[textFlagPlacement] + "[/color]"

func openEsc():
	escOpen = true

func closeEsc():
	escOpen = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if local and enabled:
		
		teleport_cooldown.value = player_node.get_node("TeleportManager").teleportCooldownTimer.get_time_left()

		if teleportMode:
			teleport.get_node("Label").text = str(stepify(player_node.get_node("TeleportManager").teleportSelectPenaltyTimer.get_time_left(), 0.1))
			teleport.get_node("TextureProgress").value = player_node.get_node("TeleportManager").teleportSelectPenaltyTimer.get_time_left()
			teleport.get_node("DamageLabel").text = "-" + str(player_node.get_node("TeleportManager").accumulatedTeleportDamage) + "HP"
		else:
			var player_list = player_node.pawnList
			var mainPawnSize = player_node.get_node("MainPawn/BodyCollision").shape.height
	
			for minion_indicator in get_tree().get_nodes_in_group("MinionIndicators"):
				if player_list.find(minion_indicator.linkedPawn) == -1:
					minion_indicator.queue_free()
			for pawn in player_list:
				if pawn.name == "MainPawn":
					minimap_gui_node.get_node("MainPawnIndicator").position = (pawn.position / minimapSize)
					minimap_gui_node.get_node("MainPawnIndicator").visible = pawn.get_node("StateManager/Sprite").visible
				else:
					if !minimap_gui_node.has_node(pawn.name + "Indicator"):
						var minion_indicator = Sprite.new()
						minion_indicator.name = pawn.name + "Indicator"
						minion_indicator.texture = load("res://assets/minimap-minion-indicator.png")
						minion_indicator.z_index = 3
						minion_indicator.set_script(indicatorScript)
						var scaleVal = (pawn.get_node("BodyCollision").shape.height/mainPawnSize) / 4
						minion_indicator.linkedPawn = pawn
						minion_indicator.scale = Vector2(scaleVal, scaleVal)
						minimap_gui_node.add_child(minion_indicator)
						minion_indicator.add_to_group("MinionIndicators")
					minimap_gui_node.get_node(pawn.name + "Indicator").position = (pawn.position / minimapSize)
					minimap_gui_node.get_node(pawn.name + "Indicator").visible = pawn.get_node("StateManager/Sprite").visible
	
			var global_camera = (get_viewport().get_visible_rect().size * get_parent().get_parent().zoom)
			minimapCamera.scale = Vector2((global_camera.x / minimapSize) / minimapCamera.texture.get_width(), (global_camera.y / minimapSize) / minimapCamera.texture.get_height())
			minimapCamera.position = get_parent().get_parent().position / minimapSize
			var currentPawn = player_node.currentActivePawn
			minimap_gui_node.get_node("SelectedPawnIndicator").position = Vector2(currentPawn.position.x / minimapSize, (currentPawn.position.y - (currentPawn.get_node("BodyCollision").shape.height) * 13) / minimapSize)
			minimap_gui_node.get_node("SelectedPawnIndicator").visible = currentPawn.get_node("StateManager/Sprite").visible
	
			var enemy_list = get_tree().get_nodes_in_group("OnScreenEntities")
			if enemy_list.size() > 0:
				for enemy in enemy_list:
					var enemy_indicator_name = str(enemy.get_parent().get_parent().name) + enemy.name + "Indicator"
					if !enemy.get_node("VisibilityNotifier").inView:
						if minimap_gui_node.has_node(enemy_indicator_name):
							minimap_gui_node.get_node(enemy_indicator_name).queue_free()
						continue
					if player_node.currentActivePawn.has_node("VisionManager") and player_node.currentActivePawn.get_node("VisionManager").underground:
						var vision_overlap_list = player_node.currentActivePawn.get_node("VisionManager").overlapping_nodes
						if vision_overlap_list.find(enemy) == -1:
							if minimap_gui_node.has_node(enemy_indicator_name):
								minimap_gui_node.get_node(enemy_indicator_name).queue_free()
							continue
					if !minimap_gui_node.has_node(enemy_indicator_name):
						var enemy_indicator = Sprite.new()
						enemy_indicator.name = enemy_indicator_name
						enemy_indicator.texture = load("res://assets/minimap-enemy-indicator.png")
						enemy_indicator.z_index = 5
						var scaleVal = (enemy.get_node("BodyCollision").shape.height/mainPawnSize) / 4
						enemy_indicator.scale = Vector2(scaleVal, scaleVal)
						minimap_gui_node.add_child(enemy_indicator)
					minimap_gui_node.get_node(enemy_indicator_name).position = (enemy.position / minimapSize)
					minimap_gui_node.get_node(enemy_indicator_name).visible = enemy.get_node("StateManager/Sprite").visible
