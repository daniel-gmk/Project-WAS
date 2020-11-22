extends Node2D

##### This node is a copy of Destructible script specifically for minimap use. 
# Physics is removed and size is reduced
# Decided to copy it in case there are drastic changes or custom changes instead of a parent-child structure

# Tracks path to destruction circle for making holes in the sprite
export var viewport_destruction_nodepath : NodePath
# Node for the destruction circle
var _viewport_destruction_node : Node

# Tracks the size of the destruction node
var world_size : Vector2
# Tracks nodes to destroy after temporarily using them
var _to_cull : Array
# Threads for that update the sprite in the background instead of interrupting the main thread
var _destruction_threads := Array()

# Copy of main texture that gets updated with new sprite with destruction
var _image_republish_texture := ImageTexture.new()
# Material that holds the sprite destruction shader
var _parent_material : Material

# Called when node loads
func _ready():
	initialize()

# Separated initialization in case manual initialization is desired
func initialize():
	
	# Setting initial variables
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

# Calling destruction of terrain from server to other clients
func destroyRPCServer(pos, rad):
	rpc("destroyRPC", pos, rad)

# Receiving call from server to locally destroy
remote func destroyRPC(pos, rad):
	destroy(pos, rad)

# Destruction (makes a hole) of terrain
func destroy(position : Vector2, radius : float):
	
	# Move our subtractive-circle so that our Viewport deletes pixels that were in our explosion
	_viewport_destruction_node.reposition(_world_to_viewport(position / 25.0), radius / 25.0)

	# Re-render the viewport into our texture
	rebuild_texture()

	# Wait until all viewports have re-rendered before pushing our viewport to the destruction shader.
	yield(VisualServer, "frame_post_draw")
	
	# Sprite rebuild thread!
	var thread2 := Thread.new()
	var error2 = thread2.start(self, "republish_sprite", [1])
	if error2 != OK:
		print("Error creating destruction thread: ", error2)
	_destruction_threads.push_back(thread2)

# Re-renders viewport
func rebuild_texture():
	# Force re-render to update our target viewport
	$Viewport.render_target_update_mode = Viewport.UPDATE_ONCE

# Updates sprite, likely after destruction
func republish_sprite(arguments : Array):
	# Assume the image has changed, so we'll need to update our ImageTexture
	_image_republish_texture.create_from_image($Sprite.texture.get_data())
	_image_republish_texture.set_flags(0)
	
	# If our parent has the proper src/destruction/parent_material shader
	# We can set our destruction_mask parameter against it, 
	# which will carve out our destruction map!
	if _parent_material != null:
		_parent_material.set_shader_param("destruction_mask", _image_republish_texture)

# Helper function to convert viewport coordinates to world coordinates
func _viewport_to_world(var point : Vector2) -> Vector2:
	var dynamic_texture_size = $Viewport.get_size()
	return Vector2(
		((point.x + get_viewport_rect().position.x) / dynamic_texture_size.x) * world_size.x,
		((point.y + get_viewport_rect().position.y) / dynamic_texture_size.y) * world_size.y
	)

# Helper function to convert world coordinates to viewport coordinates
func _world_to_viewport(var point : Vector2) -> Vector2:
	var dynamic_texture_size = $Viewport.get_size()
	var parent_offset = get_parent().position
	return Vector2(
		(((point.x - parent_offset.x ) / world_size.x) * dynamic_texture_size.x + get_viewport_rect().position.x),
		(((point.y - parent_offset.y ) / world_size.y) * dynamic_texture_size.y + get_viewport_rect().position.y)
	)

# Removes duplicate nodes used to copy the parent into local viewport to make changes to it
func _cull_foreground_duplicates():
	for dup in _to_cull:
		dup.queue_free()
	_to_cull = Array()

# Purging threads when node is destroyed
func _exit_tree():
	for thread in _destruction_threads:
		thread.wait_to_finish()
