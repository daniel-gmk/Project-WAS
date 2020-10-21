extends Control


# Declare member variables here. Examples:
# var a = 2
export var minimap_gui_nodepath : NodePath
var minimap_gui_node
var minimap_node
var minimapSize
var minimapCamera

# Called when the node enters the scene tree for the first time.
func _ready():
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
	if !get_tree().is_network_server():
		var player_node = get_parent().get_parent().get_parent()
		var player_list = player_node.pawnList
		var mainPawnSize = player_node.get_node("MainPawn/BodyCollision").shape.height
		for pawn in player_list:
			if pawn.name == "MainPawn":
				minimap_gui_node.get_node("MainPawnIndicator").position = (pawn.position / minimapSize)
				minimap_gui_node.get_node("MainPawnIndicator").visible = pawn.visible
			else:
				if !minimap_gui_node.has_node(pawn.name + "Indicator"):
					var minion_indicator = Sprite.new()
					minion_indicator.name = pawn.name + "Indicator"
					minion_indicator.texture = load("res://assets/minimap-minion-indicator.png")
					minion_indicator.z_index = 3
					var scaleVal = (pawn.get_node("BodyCollision").shape.height/mainPawnSize) / 4
					minion_indicator.scale = Vector2(scaleVal, scaleVal)
					minimap_gui_node.add_child(minion_indicator)
				minimap_gui_node.get_node(pawn.name + "Indicator").position = (pawn.position / minimapSize)
				minimap_gui_node.get_node(pawn.name + "Indicator").visible = pawn.visible

		var global_camera = (get_node("/root/").size * get_parent().get_parent().zoom)
		minimapCamera.scale = Vector2((global_camera.x / minimapSize) / minimapCamera.texture.get_width(), (global_camera.y / minimapSize) / minimapCamera.texture.get_height())
		minimapCamera.position = get_parent().get_parent().position / minimapSize
		var currentPawn = player_node.currentActivePawn
		minimap_gui_node.get_node("SelectedPawnIndicator").position = Vector2(currentPawn.position.x / minimapSize, (currentPawn.position.y - (currentPawn.get_node("BodyCollision").shape.height) * 13) / minimapSize)
		minimap_gui_node.get_node("SelectedPawnIndicator").visible = currentPawn.visible
