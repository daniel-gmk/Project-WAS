extends VisibilityNotifier2D

##### This node detects whether the parent node is on-screen on the main viewport/camera, currently primarily for minimap

# Tracks whether the node is on-screen
var inView = false
# Tracks the instantiated player node that owns this node
var player_node

# Called when the node is initialized
func initialize():
	# No need to detect a self-owned node as of now
	player_node = get_parent().player_node
	if player_node.control:
		queue_free()
	# Connect events when on screen or off screen
	connect("screen_entered", self, "_on_screen_entered")
	connect("screen_exited", self, "_on_screen_exited")

# When node enters screen
func _on_screen_entered():
	if !player_node.control:
		get_parent().add_to_group("OnScreenEntities")
		inView = true

# When node leaves screen
func _on_screen_exited():
	inView = false
