extends Area2D

##### This node handles the minion cursor icon that shows whether the location at cursor is valid to summon a minion on

# Sets visuals for allowed/not allowed teleporting
func _physics_process(_delta : float):
	if get_overlapping_bodies().size() == 0:
		get_parent().modulate = Color(0, 1, 0) # Green shade
	else:
		get_parent().modulate = Color(1, 0, 0) # Red shade
