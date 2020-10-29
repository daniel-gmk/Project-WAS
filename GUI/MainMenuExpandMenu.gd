extends ScrollContainer

var is_expanded = false


func _ready():
	if name == "PlayScrollContainer":
		get_parent().get_node("PlayButton").connect("pressed",self,"expand")
	elif name == "CustomizeScrollContainer":
		get_parent().get_node("CustomizeButton").connect("pressed",self,"expand")

func expand():
	is_expanded = !is_expanded


var last_rect_size = Vector2.ZERO
func _process(delta):

	#snap to end
	if abs(rect_size.y-rect_min_size.y) < 1:
		rect_size.y = rect_min_size.y

	#resize to target size
	if is_expanded:
		rect_size.y = lerp(rect_size.y, 90, 0.1)
	else:
		rect_size.y = lerp(rect_size.y, rect_min_size.y, 0.1)

	#update layout
	if last_rect_size != rect_size:
		get_parent().update()
		last_rect_size = rect_size
