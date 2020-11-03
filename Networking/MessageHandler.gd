extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func sendMessageToServer(message, player_id, flagPlacement, systemMessage):
	rpc_id(1, "sendMessageServer", message, player_id, flagPlacement, systemMessage)

func sendMessageAsServer(message, player_id, flagPlacement, systemMessage):
	rpc("sendMessageRPC", message, player_id, flagPlacement, systemMessage)
	if int(player_id) != get_tree().get_network_unique_id():
		for gui_node_in_group in get_tree().get_nodes_in_group("GUI"):
			gui_node_in_group.sendMessage(message, player_id, flagPlacement, systemMessage)

remote func sendMessageServer(message, player_id, flagPlacement, systemMessage):
	rpc("sendMessageRPC", message, player_id, flagPlacement, systemMessage)
	if int(player_id) != get_tree().get_network_unique_id():
		for gui_node_in_group in get_tree().get_nodes_in_group("GUI"):
			gui_node_in_group.sendMessage(message, player_id, flagPlacement, systemMessage)

remote func sendMessageRPC(message, player_id, flagPlacement, systemMessage):
	if int(player_id) != get_tree().get_network_unique_id():
		for gui_node_in_group in get_tree().get_nodes_in_group("GUI"):
			gui_node_in_group.sendMessage(message, player_id, flagPlacement, systemMessage)
