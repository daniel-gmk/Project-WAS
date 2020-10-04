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
# Stores the player's MainPawn child for when the player is being focused.
var playerOwner

var shiftHolding = false

func _ready() -> void:
	if get_tree().is_network_server() or !get_parent().control:
		queue_free()
	# Set camera focus to player
	target = get_parent().get_node("MainPawn")
	playerOwner = get_parent().get_node("MainPawn")
	root = get_parent()
	lastPlayerOwnerPosition = false
	make_current()
	current_position = position

func _input(event):
	if event.is_action_pressed("shift"):
		shiftHolding = true

	if event.is_action_released("shift"):
		shiftHolding = false

func _physics_process(delta: float) -> void:
	if !lastPlayerOwnerPosition:
		destination_position = target.position
		current_position += Vector2(destination_position.x - current_position.x, destination_position.y - current_position.y) / SMOOTHING_DURATION * delta
		
		position = current_position.round()
		force_update_scroll()

func _unhandled_input(event):
	if get_parent().control:
		# Handles the initial and final trigger for dragging the camera
		if event is InputEventMouseButton and event.button_index == BUTTON_RIGHT:
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
		if event.is_action_pressed("reset_camera"):
			lastPlayerOwnerPosition = false
			position = Vector2.ZERO
			current_position = playerOwner.position
	
		# Handle panning when dragging the camera
		elif event is InputEventMouseMotion and _move_camera:
			get_tree().set_input_as_handled()
			position += (_previous_position - event.position)
			_previous_position = event.position
	
		# Zoom, this will be turned off for non-spectators eventually
		elif event is InputEventMouseButton and event.pressed and shiftHolding:
			var new_zoom := Vector2.ZERO
			if event.button_index == BUTTON_WHEEL_UP:
				new_zoom = zoom.linear_interpolate(Vector2(0.5, 0.5), 0.2)
			elif event.button_index == BUTTON_WHEEL_DOWN:
				new_zoom = zoom.linear_interpolate(Vector2(1,1), 0.2)
			
			if (new_zoom != Vector2.ZERO):
				get_tree().set_input_as_handled()
				zoom = new_zoom

func switchFromPlayerCamera():
	# Reset current camera
	lastPlayerOwnerPosition = false
	position = Vector2.ZERO
	get_parent().currentActivePawn.get_node("MovementInputManager").movement.x = 0
	# Remove current camera
	clear_current()
	# Set mouse location and view
	get_viewport().warp_mouse(get_viewport_rect().size / 2)

func switchToPlayerCamera():
	# Set mouse location and view
	get_viewport().warp_mouse(get_viewport_rect().size / 2)
	get_parent().currentActivePawn.get_node("MovementInputManager").movement.x = 0
	# Set new pawn camera
	make_current()
	# Reset camera position
	lastPlayerOwnerPosition = false
	position = Vector2.ZERO

func hideCamera():
	# Disable HUD
	get_node("CanvasLayer").get_node("GUI").visible = false

func showCamera():
	# Enable HUD
	get_node("CanvasLayer").get_node("GUI").visible = true

func changeTarget(node):
	target = node
	playerOwner = node
