extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func setCamera():
	$TeleportCamera.make_current()

func clearCamera():
	$TeleportCamera.clear_current()

func setCameraLocation(map_center_location):
	$TeleportCamera.mainPosition = map_center_location
	$TeleportCamera.position = map_center_location

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$Sprite.position = get_global_mouse_position()

func _input(event):
	if event.is_action_pressed("shoot"):
		if $Sprite.get_node("Area2D").get_overlapping_bodies().size() == 0:
			get_parent().requestTeleportToServer($Sprite.position)
