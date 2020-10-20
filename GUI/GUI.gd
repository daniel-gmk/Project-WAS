extends Control


# Declare member variables here. Examples:
# var a = 2
export var minimap_gui_nodepath : NodePath
var minimap_gui_node
var minimap_node

# Called when the node enters the scene tree for the first time.
func _ready():
	minimap_gui_node = get_node(minimap_gui_nodepath)
	minimap_node = get_node("/root/environment/TestMap").minimapNode
	minimap_node.get_parent().remove_child(minimap_node)
	minimap_gui_node.add_child(minimap_node)
	minimap_node.set_owner(minimap_gui_node)
	minimap_node.z_index = 1

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var player_list = get_parent().get_parent().get_parent().pawnList
	for pawn in player_list:
		if pawn.name == "MainPawn":
			minimap_gui_node.get_node("MainPawnIndicator").position = (pawn.position / 25)
