extends Camera2D

### Handles camera attached to the player. Camera focus can be on player or map
# Track previous position
var _previous_position : Vector2 = Vector2.ZERO


# Track if camera is panned
var _move_camera := false
# Tracks if the camera is focused on player
var lastPlayerOwnerPosition = false

### Variables passed from root
# Stores the player's root node for when the player is not being focused.
var root
# Stores the player's MainPawn child for when the player is being focused.
var playerOwner
# Decides if this is the local player so this only happens to the local player character.
var control = false

func _unhandled_input(event):
	# Handles the initial and final trigger for dragging the camera
	if event is InputEventMouseButton and event.button_index == BUTTON_RIGHT and control:
		get_tree().set_input_as_handled()
		if event.is_pressed():
			if lastPlayerOwnerPosition == false:
				position = playerOwner.position
				lastPlayerOwnerPosition = true
			_previous_position = event.position
			_move_camera = true
			changeToRoot()
		else:
			_move_camera = false

	# Handle panning when dragging the camera
	elif event is InputEventMouseMotion and _move_camera and control:
		get_tree().set_input_as_handled()
		changeToRoot()
		position += (_previous_position - event.position)
		_previous_position = event.position

	# Zoom, this will be turned off for non-spectators eventually
	elif event is InputEventMouseButton and control:
		var new_zoom := Vector2.ZERO
		if event.button_index == BUTTON_WHEEL_UP:
			new_zoom = zoom.linear_interpolate(Vector2(0.5, 0.5), 0.2)
		elif event.button_index == BUTTON_WHEEL_DOWN:
			new_zoom = zoom.linear_interpolate(Vector2(2,2), 0.2)
		
		if (new_zoom != Vector2.ZERO):
			get_tree().set_input_as_handled()
			zoom = new_zoom

# Handles changing focus to the player (or specifically, the MainPawn)
func changeToPlayerOwner():
	print("yes")
	#get_parent().remove_child(self)
	#playerOwner.add_child(self)

# Handles changing focus off the player to allow panning around the map
func changeToRoot():
	get_parent().remove_child(self)
	root.add_child(self)
