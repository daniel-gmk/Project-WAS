extends ColorRect

##### Handles logic for menu opened to discard changes from settings footer

# Confirmed changes button
func _on_ResetButton_pressed():
	get_parent().discardSettings()
	queue_free()

# Cancel changes button
func _on_CancelButton_pressed():
	queue_free()
