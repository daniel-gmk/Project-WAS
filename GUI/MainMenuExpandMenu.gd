extends ScrollContainer

##### This node handles collapsing and expanding of the main menu options that have sub menus

# Tracks if main menu is expanded or not
var is_expanded = false

# Tracks previous size of element
var last_rect_size = Vector2.ZERO

# When the node loads
func _ready():
	# Connects functionality to certain menu items
	if name == "PlayScrollContainer":
		get_parent().get_node("PlayButton").connect("pressed",self,"expand")
	elif name == "CustomizeScrollContainer":
		get_parent().get_node("CustomizeButton").connect("pressed",self,"expand")

# Toggles expansion of menu
func expand():
	is_expanded = !is_expanded

# Loads every frame
func _process(delta):

	# Snap to end
	if abs(rect_size.y-rect_min_size.y) < 1:
		rect_size.y = rect_min_size.y

	# Resize to target size
	if is_expanded:
		rect_size.y = lerp(rect_size.y, 90, 0.1)
	else:
		rect_size.y = lerp(rect_size.y, rect_min_size.y, 0.1)

	# Update layout
	if last_rect_size != rect_size:
		get_parent().update()
		last_rect_size = rect_size
