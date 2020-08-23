extends Camera2D


var _previous_position : Vector2 = Vector2.ZERO
var _move_camera := false
var lastPlayerOwnerPosition = false
var playerOwner
var root
var control = false

func _unhandled_input(event):
	# Click and drag - begin / end clicking
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

	# Reset camera
	if event.is_action_pressed("reset_camera") and control:
		changeToPlayerOwner()
		lastPlayerOwnerPosition = false
		position = Vector2.ZERO

	# Click and drag - dragging
	elif event is InputEventMouseMotion and _move_camera and control:
		get_tree().set_input_as_handled()
		changeToRoot()
		position += (_previous_position - event.position)
		_previous_position = event.position

	# Zoom, turn off eventually
	elif event is InputEventMouseButton and control:
		var new_zoom := Vector2.ZERO
		if event.button_index == BUTTON_WHEEL_UP:
			new_zoom = zoom.linear_interpolate(Vector2(0.5, 0.5), 0.2)
		elif event.button_index == BUTTON_WHEEL_DOWN:
			new_zoom = zoom.linear_interpolate(Vector2(4,4), 0.2)
		
		if (new_zoom != Vector2.ZERO):
			get_tree().set_input_as_handled()
			zoom = new_zoom

func changeToPlayerOwner():
	get_parent().remove_child(self)
	playerOwner.add_child(self)

func changeToRoot():
	get_parent().remove_child(self)
	root.add_child(self)
