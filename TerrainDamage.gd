extends Area2D

var size

func setSize(val):
	size = val
	$RadialShape.setSize(val)

func setExplosion():
	# This buffers/waits for two physics frames because the way godot works is that a Physics handler flushes out data
	# and it takes a frame or two to do that. Apparently it needs to do that or else this won't detect anything.
	# Remember to yield two frames for clients too, or at least explore if this builds up over the game and causes desync
	# Since only the server will buffer 2 frames every explosion and not the client
	yield(get_parent().get_tree(), "physics_frame")
	yield(get_parent().get_tree(), "physics_frame")

	var overlap_terrain = get_overlapping_bodies()
	get_node("/root/").get_node("1").destroyTerrainServerRPC(overlap_terrain, position, size)

	queue_free()
