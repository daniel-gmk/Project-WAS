extends VisibilityNotifier2D

var inView = false

# Called when the node enters the scene tree for the first time.
func _ready():
	if int(get_parent().get_parent().get_parent().name) == get_tree().get_network_unique_id():
		queue_free()
	connect("screen_entered", self, "_on_screen_entered")
	connect("screen_exited", self, "_on_screen_exited")

func _on_screen_entered():
	if int(get_parent().get_parent().get_parent().name) != get_tree().get_network_unique_id():
		get_parent().add_to_group("OnScreenEntities")
		inView = true

func _on_screen_exited():
	inView = false
