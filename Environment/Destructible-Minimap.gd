extends Node2D

### This node is in charge of terrain generation, destruction, and updating. Main component of Destructible.tscn.
# This component was created by someone else so it isn't as well documented by me until I need to modify it

export var viewport_destruction_nodepath : NodePath
export var collision_holder_node_path : NodePath

var world_size : Vector2

var collision_holder : Node2D
var _to_cull : Array

var _image_republish_texture := ImageTexture.new()

var _parent_material : Material
var _destruction_threads := Array()
var _viewport_destruction_node : Node

func _ready():
	readyFunc()
	
func readyFunc():
	
	collision_holder = get_node(collision_holder_node_path)
	world_size = (get_parent() as Sprite).get_rect().size
	_parent_material = get_parent().material
	_viewport_destruction_node = get_node(viewport_destruction_nodepath)
	
	# Set our viewport size. We don't know this until run time, since its from our parent.
	$Viewport.set_size(world_size)
	
	# Passing 0 to duplicate, as we don't want to duplicate scripts/signals etc
	# We don't use 8 since we're going to delete our duplicate nodes after first render anyway
	var dup = get_parent().duplicate(0) as Node2D
	_to_cull.append(dup)
	
	# Then reposition, so we're in the right spot
	dup.position = _world_to_viewport(dup.position)

	# Add to the viewport, so that our destructible viewport has our starting point
	$Viewport.add_child(dup)
	
	# Start the timer, so it can delete our duplicated parent info
	$CullTimer.start()
	
	# Wait for all viewports to re-render before we build our image
	yield(VisualServer, "frame_post_draw")

func calculate_bounds(tilemap):
	var cell_bounds = tilemap.get_used_rect()
	# create transform
	var cell_to_pixel = Transform2D(Vector2(tilemap.cell_size.x * tilemap.scale.x, 0), Vector2(0, tilemap.cell_size.y * tilemap.scale.y), Vector2())
	# apply transform
	return Rect2(cell_to_pixel * cell_bounds.position, cell_to_pixel * cell_bounds.size).size

func _exit_tree():
	for thread in _destruction_threads:
		thread.wait_to_finish()


func _unhandled_input(event):
	if (event.is_action_pressed("ui_accept")):
		# DEBUG:
		var bitmap := BitMap.new()
		bitmap.create_from_image_alpha($Sprite.texture.get_data())
		$Sprite.get_texture().get_data().save_png("res://screenshots/debug" + get_parent().name + ".png")

func destroyRPCServer(pos, rad):
	rpc("destroyRPC", pos, rad)

remote func destroyRPC(pos, rad):
	destroy(pos, rad)

func destroy(position : Vector2, radius : float):
	
	# Move our subtractive-circle so that our Viewport deletes pixels that were in our explosion
	_viewport_destruction_node.reposition(_world_to_viewport(position / 25.0), radius / 25.0)
	# Re-render the viewport into our texture
	
	rebuild_texture()
	
	#get_node("/root/environment/MiniMap/Destructible").destroy(position * (1/30), radius * 1/30)

	# Wait until all viewports have re-rendered before pushing our viewport to the destruction shader.
	yield(VisualServer, "frame_post_draw")
	
	if !get_tree().is_network_server():
		# Sprite rebuild thread!
		var thread2 := Thread.new()
		var error2 = thread2.start(self, "republish_sprite", [1])
		if error2 != OK:
			print("Error creating destruction thread: ", error2)
		_destruction_threads.push_back(thread2)

func _cull_foreground_duplicates():
	for dup in _to_cull:
		dup.queue_free()
	_to_cull = Array()


func rebuild_texture():
	# Force re-render to update our target viewport
	$Viewport.render_target_update_mode = Viewport.UPDATE_ONCE

func republish_sprite(arguments : Array):
	# Assume the image has changed, so we'll need to update our ImageTexture
	_image_republish_texture.create_from_image($Sprite.texture.get_data())
	_image_republish_texture.set_flags(0)
	
	# If our parent has the proper src/destruction/parent_material shader
	# We can set our destruction_mask parameter against it, 
	# which will carve out our destruction map!
	if _parent_material != null:
		_parent_material.set_shader_param("destruction_mask", _image_republish_texture)


func _viewport_to_world(var point : Vector2) -> Vector2:
	var dynamic_texture_size = $Viewport.get_size()
	return Vector2(
		((point.x + get_viewport_rect().position.x) / dynamic_texture_size.x) * world_size.x,
		((point.y + get_viewport_rect().position.y) / dynamic_texture_size.y) * world_size.y
	)


func _world_to_viewport(var point : Vector2) -> Vector2:
	var dynamic_texture_size = $Viewport.get_size()
	var parent_offset = get_parent().position
	return Vector2(
		(((point.x - parent_offset.x ) / world_size.x) * dynamic_texture_size.x + get_viewport_rect().position.x),
		(((point.y - parent_offset.y ) / world_size.y) * dynamic_texture_size.y + get_viewport_rect().position.y)
	)
