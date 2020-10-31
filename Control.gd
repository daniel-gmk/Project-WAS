extends Control

### Temporary menu attached to root for hosting or joining, replacing with lobby system

func _ready():
	if "--server" in OS.get_cmdline_args():
		print("Server detected")
		var network = get_node("/root/Network")
		network.start_server()
	
# Button function for starting server
func _on_CreateButton_pressed():
	var network = get_node("/root/Network")
	network.start_server_dedicated()
	$CreateWithDedicated.queue_free()

# Button function for joining server
func _on_JoinButton_pressed():
	var network = get_node("/root/Network")
	var text = get_node("LineEdit").get_text()
	network.join_server(text)
	get_parent().remove_child(self)

# Button function for starting game from the server
func _on_Startbutton_pressed():
	var network = get_node("/root/Network")
	network.start_game()
	get_parent().remove_child(self)

func _on_CreateWithP2P_pressed():
	var network = get_node("/root/Network")
	network.start_server_peertopeer()
	$CreateWithP2P.queue_free()
	
