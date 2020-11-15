extends Camera2D

##### Handles camera attached to the player. Camera focus can be on player or map

# Tracks whether the node is initialized
var initialized = false

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

# Called when node is initialized
func initialize():
	# Remove the camera if not local, no one else has a use for it
	if !get_parent().control:
		queue_free()
	# Set camera focus to player
	root = get_parent()
	target = get_parent().currentActivePawn
	playerOwner = target
	lastPlayerOwnerPosition = false
	# Set location
	current_position = position
	# Initialize GUI
	get_node("CanvasLayer/GUI").camera_node = self
	get_node("CanvasLayer/GUI").initialize(get_parent())
	
	# Initialize the node
	initialized = true

# Called every physics node
func _physics_process(delta: float) -> void:
	# If focused on a player, interpolate to the player position (smoothing effect)
	if initialized and !lastPlayerOwnerPosition:
		destination_position = target.position
		current_position += Vector2(destination_position.x - current_position.x, destination_position.y - current_position.y) / SMOOTHING_DURATION * delta
		
		position = current_position.round()
		force_update_scroll()

# Handle input
func _unhandled_input(event):
	if initialized and get_parent().control and !get_parent().menuPressed:
		# Handles the initial and final trigger for dragging the camera
		if event.is_action_pressed("DragCamera") or event.is_action_released("DragCamera"):
			get_tree().set_input_as_handled()
			if event.is_action_pressed("DragCamera"):
				if lastPlayerOwnerPosition == false:
					position = playerOwner.position
					lastPlayerOwnerPosition = true
				_previous_position = event.position
				_move_camera = true
			elif event.is_action_released("DragCamera"):
				_move_camera = false
	
		# Reset camera focus back to the player when reset button is pressed
		if event.is_action_pressed("ResetCamera"):
			lastPlayerOwnerPosition = false
			position = Vector2.ZERO
			current_position = playerOwner.position
	
		# Handle panning when dragging the camera
		elif event is InputEventMouseMotion and _move_camera:
			get_tree().set_input_as_handled()
			position += (_previous_position - event.position)
			_previous_position = event.position
	
		# Zoom, this will be turned off for non-spectators eventually
		elif event.is_action_pressed("CameraZoomIn") or event.is_action_pressed("CameraZoomOut"):
			var new_zoom := Vector2.ZERO
			if event.is_action_pressed("CameraZoomIn"):
				new_zoom = zoom.linear_interpolate(Vector2(0.5, 0.5), 0.2)
			elif event.is_action_pressed("CameraZoomOut"):
				new_zoom = zoom.linear_interpolate(Vector2(1,1), 0.2)
			
			if (new_zoom != Vector2.ZERO):
				get_tree().set_input_as_handled()
				zoom = new_zoom

# Handle when switched from focusing on a pawn to free panning
func switchFromPlayerCamera():
	# Reset current camera
	lastPlayerOwnerPosition = false
	position = Vector2.ZERO
	get_parent().currentActivePawn.get_node("MovementInputManager").movement.x = 0
	# Remove current camera
	clear_current()
	# Set mouse location and view
	get_viewport().warp_mouse(get_viewport_rect().size / 2)

# Handle when switching from free panning to a pawn
func switchToPlayerCamera():
	# Set mouse location and view
	get_viewport().warp_mouse(get_viewport_rect().size / 2)
	get_parent().currentActivePawn.get_node("MovementInputManager").movement.x = 0
	# Set new pawn camera
	make_current()
	# Reset camera position
	lastPlayerOwnerPosition = false
	position = Vector2.ZERO

# Hide the GUI
func hideCamera():
	# Disable HUD
	if has_node("CanvasLayer/GUI"):
		get_node("CanvasLayer").get_node("GUI").visible = false

# Show the GUI
func showCamera():
	# Enable HUD
	if has_node("CanvasLayer/GUI"):
		get_node("CanvasLayer").get_node("GUI").visible = true

# Change to a different pawn target
func changeTarget(node):
	target = node
	playerOwner = node
