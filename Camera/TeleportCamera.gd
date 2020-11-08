extends Camera2D

##### Node handles camera when teleporting is happening
# Tracks player that owns this node
var player_node
# Tracks whether the node is initialized
var initialized = false
# Tracks the anchor position of the camera, which is likely center of the map
var mainPosition

# Called to initialize node
func initialize(playerNode):
	# Set Variables
	player_node = playerNode
	get_node("CanvasLayer/GUI").camera_node = self
	# Initialize GUI
	get_node("CanvasLayer/GUI").initialize(player_node)
	# Set initialized on
	initialized = true

# Upon keyboard input
func _input(event):
	if initialized:
		# Zoom on scrolling
		if event is InputEventMouseButton and !get_parent().get_parent().menuPressed:
			var new_zoom := Vector2.ZERO
			if event.button_index == BUTTON_WHEEL_UP:
				position = position.linear_interpolate(get_global_mouse_position(), 0.2)
				new_zoom = zoom.linear_interpolate(Vector2(0.5, 0.5), 0.2)
			elif event.button_index == BUTTON_WHEEL_DOWN:
				new_zoom = zoom.linear_interpolate(Vector2(6,6), 0.2)
				position = position.linear_interpolate(mainPosition, 0.2)
			
			if (new_zoom != Vector2.ZERO):
				get_tree().set_input_as_handled()
				zoom = new_zoom
