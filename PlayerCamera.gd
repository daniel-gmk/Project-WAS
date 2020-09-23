extends Camera2D

### Handles camera attached to the player. Camera focus can be on player or map

# Smoothing duration in seconds
const SMOOTHING_DURATION: = 0.2

# The node to follow
var target: Node2D = null

# Current position of the camera
var current_position: Vector2

# Position the camera is moving towards
var destination_position: Vector2

# Track previous position
var _previous_position : Vector2 = Vector2.ZERO
# Track if camera is panned
var _move_camera := false
# Tracks if the camera is focused on player
var lastPlayerOwnerPosition = true

### Variables passed from root
# Stores the player's root node for when the player is not being focused.
var root
# Stores the player's playerPhysicsBody child for when the player is being focused.
var playerOwner
# Decides if this is the local player so this only happens to the local player character.
var control = false

func _ready() -> void:
	current_position = position

func _physics_process(delta: float) -> void:
	if !lastPlayerOwnerPosition:
		destination_position = target.position
		current_position += Vector2(destination_position.x - current_position.x, destination_position.y - current_position.y) / SMOOTHING_DURATION * delta
		
		position = current_position.round()
		force_update_scroll()

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
		else:
			_move_camera = false

	# Reset camera focus back to the player when reset button is pressed
	if event.is_action_pressed("reset_camera") and control:
		lastPlayerOwnerPosition = false
		position = Vector2.ZERO
		current_position = playerOwner.position

	# Handle panning when dragging the camera
	elif event is InputEventMouseMotion and _move_camera and control:
		get_tree().set_input_as_handled()
		position += (_previous_position - event.position)
		_previous_position = event.position

	# Zoom, this will be turned off for non-spectators eventually
	elif event is InputEventMouseButton and control:
		var new_zoom := Vector2.ZERO
		if event.button_index == BUTTON_WHEEL_UP:
			new_zoom = zoom.linear_interpolate(Vector2(0.5, 0.5), 0.2)
		elif event.button_index == BUTTON_WHEEL_DOWN:
			new_zoom = zoom.linear_interpolate(Vector2(1,1), 0.2)
		
		if (new_zoom != Vector2.ZERO):
			get_tree().set_input_as_handled()
			zoom = new_zoom
