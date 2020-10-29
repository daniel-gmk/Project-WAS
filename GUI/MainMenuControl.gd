extends Control

export var spacing = 20

func _draw():

	var last_end_achor = Vector2(40,rect_size.y - 450)
	var temp_children_array = get_children()
	for child in temp_children_array:
		if child.name != "ColorRect" and child.name != "Character" and child.name != "ExitMenu":
			child.rect_position = last_end_achor
			last_end_achor.y = child.rect_position.y + child.rect_size.y 
			if child.get_class() == "ScrollContainer":
				child.rect_position.y -= 10
			else:
				last_end_achor.y += spacing

	rect_min_size.y = last_end_achor.y #to work with ScrollContainer


func _on_QuickPlayButton_pressed():
	get_tree().change_scene("res://Multiplayer.tscn")

func _on_ExitButton_pressed():
	get_node("ExitMenu").visible = true

func _on_ExitConfirm_pressed():
	get_tree().quit()

func _on_ExitCancel_pressed():
	get_node("ExitMenu").visible = false
