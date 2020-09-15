extends Camera2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
var mainPosition

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
func _input(event):
	#if event is InputEventMouseMotion:
	#	position = get_global_mouse_position()

	if event is InputEventMouseButton:
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
