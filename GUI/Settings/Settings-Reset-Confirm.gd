extends ColorRect

##### Handles logic for menu opened to reset changes from settings footer

# Confirmed changes button
func _on_ResetButton_pressed():
	get_parent().resetSettings()
	queue_free()

# Cancel changes button
func _on_CancelButton_pressed():
	queue_free()
