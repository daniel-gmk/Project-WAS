extends Control


func _on_CreateButton_pressed():
	var network = get_node("/root/Network")
	network.start_server()
	get_parent().remove_child(self)


func _on_JoinButton_pressed():
	var network = get_node("/root/Network")
	network.join_server()
	get_parent().remove_child(self)
