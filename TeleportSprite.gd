extends Area2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _physics_process(_delta : float):
	if get_overlapping_bodies().size() == 0:
		get_parent().modulate = Color(0, 1, 0) # Green shade
	else:
		get_parent().modulate = Color(1, 0, 0) # Red shade
