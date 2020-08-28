extends Control

### Temporary menu attached to root for hosting or joining, replacing with lobby system

# Button function for starting server
func _on_CreateButton_pressed():
	var network = get_node("/root/Network")
	network.start_server()
	get_parent().remove_child(self)

# Button function for joining server
func _on_JoinButton_pressed():
	var network = get_node("/root/Network")
	var text = get_node("LineEdit").get_text()
	network.join_server(text)
	get_parent().remove_child(self)
