extends ColorRect

##### Tracks button and base functionality of escape menu

# When resume is pressed
func _on_ResumeButton_pressed():
	get_parent().closeEsc()

# When settings is pressed
func _on_SettingsButton_pressed():
	visible = false
	get_parent().addSettings()
