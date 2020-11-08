extends Node2D

##### This node handles messaging between server and client for chat

# Wrapper for client to call server
func sendMessageToServer(message, player_id, flagPlacement, systemMessage):
	rpc_id(1, "sendMessageServer", message, player_id, flagPlacement, systemMessage)

# Wrapper for server receiving call from client to execute
remote func sendMessageServer(message, player_id, flagPlacement, systemMessage):
	sendMessageAsServer(message, player_id, flagPlacement, systemMessage)

# Wrapper for server calling locally and broadcasting back to all clients
func sendMessageAsServer(message, player_id, flagPlacement, systemMessage):
	rpc("sendMessageRPC", message, player_id, flagPlacement, systemMessage)
	sendMessage(message, player_id, flagPlacement, systemMessage)

# Wrapper for clients to recieve call from server to call locally
remote func sendMessageRPC(message, player_id, flagPlacement, systemMessage):
	sendMessage(message, player_id, flagPlacement, systemMessage)

# Sends message to chat menus
func sendMessage(message, player_id, flagPlacement, systemMessage):
	if int(player_id) != get_tree().get_network_unique_id():
			for gui_node_in_group in get_tree().get_nodes_in_group("GUI"):
				gui_node_in_group.sendMessage(message, player_id, flagPlacement, systemMessage)
