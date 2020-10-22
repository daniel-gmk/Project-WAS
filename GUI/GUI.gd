extends Control


# Declare member variables here. Examples:
# var a = 2
export var minimap_gui_nodepath : NodePath
var minimap_gui_node
var minimap_node
var minimapSize
var minimapCamera
var player_node
var local = false
var indicatorScript

# Called when the node enters the scene tree for the first time.
func _ready():
	player_node = get_parent().get_parent().get_parent()
	indicatorScript = preload("res://GUI/Indicator.gd")
	if !get_tree().is_network_server() and int(player_node.get_parent().name) == get_tree().get_network_unique_id():
		local = true
		var testMap = get_node("/root/environment/TestMap")
		minimap_gui_node = get_node(minimap_gui_nodepath)
		minimap_node = testMap.minimapNode
		minimapSize = testMap.minimapRatio
		minimap_node.get_parent().remove_child(minimap_node)
		minimap_gui_node.add_child(minimap_node)
		minimap_node.set_owner(minimap_gui_node)
		minimap_node.z_index = 1
		minimapCamera = minimap_gui_node.get_node("CameraIndicator")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if local and !player_node.get_node("TeleportManager").teleporting:
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
				var enemy_indicator_name = str(player_node.get_parent().name) + enemy.name + "Indicator"
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
