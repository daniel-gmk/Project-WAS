extends Control

##### This node controls how the main menu works, it places each element in the correct spot and order and controls button functionality

# Spacing between each menu item
export var spacing = 20

# Drawing the UI every frame
func _draw():
	# Make sure its positioned 40 px from the left, starts 450px from the top
	var last_end_anchor = Vector2(40,rect_size.y - 450)
	var temp_children_array = get_children()
	for child in temp_children_array:
		# Ignore certain elements
		if child.name != "ColorRect" and child.name != "Character" and child.name != "ExitMenu":
			# Set position based on previous element
			child.rect_position = last_end_anchor
			last_end_anchor.y = child.rect_position.y + child.rect_size.y 
			if child.get_class() == "ScrollContainer":
				child.rect_position.y -= 10
			else:
				last_end_anchor.y += spacing

	rect_min_size.y = last_end_anchor.y #to work with ScrollContainer

# Opens multiplayer menu
func _on_QuickPlayButton_pressed():
	get_tree().change_scene("res://Multiplayer.tscn")

# Initial exit button, opens confirmation menu
func _on_ExitButton_pressed():
	get_node("ExitMenu").visible = true

# Confirmation on exit, exits game
func _on_ExitConfirm_pressed():
	get_tree().quit()

# Cancelation on exit, goes back to menu
func _on_ExitCancel_pressed():
	get_node("ExitMenu").visible = false
