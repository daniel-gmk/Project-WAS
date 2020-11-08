extends Node2D

##### This node handles fog of war and vision to parents this is attached to. This is a custom in-game mechanic.

### Main variables
# Tracks the calling player node that owns this node
var player_node
# Tracks whether this module is initialized
var initialized = false

### VisionManager Main variables
# Tracks whether the pawn's line of sight to the sky is blocked
var underground = false
# Tracks the current size of vision
var currentLightSize
# Tracks the updated/target size of vision to interpolate to
var newLightSize
# Tracks the size of maximum vision
var originalLightSize
# Timer that tracks the update rate of vision
var skyRaycastTimer = Timer.new()
# Tracks nodes that are within vision vicinity, currenly only used for minimap
var overlapping_nodes = []

### VisionManager Map variables
# Tracks the map's dimensions to determine adequate vision size/scale
var mapWidth
var mapHeight
var mapDiag

### VisionManager Vision tuning variables
# Tuning parameters that affect the growth/shrink rate of light
export var lightModifier = .2
# Minimum size of light
export var lightMin = .125
# Maximum size of light
export var lightMax = 12
# How many pixels in the light image from the edge is black, inverse of this is the radius of the light circle
export var lightTextureOffset = 245

# Called when the node is initialized
func initialize():
	# Set initial variables
	player_node = get_parent().player_node
	if !player_node.control:
		queue_free()

	# Receive map data 
	mapWidth = get_node(player_node.map_path).maxLength
	mapHeight = get_node(player_node.map_path).maxHeight
	mapDiag = sqrt((mapWidth * mapWidth) + (mapHeight * mapHeight))

	# Set raycast check to sky to detect underground variable
	$SkyRaycastCheck.add_exception(get_parent())
	$SkyRaycastCheck.cast_to = Vector2(0,mapHeight)

	# Set timer for light update rate
	skyRaycastTimer.set_wait_time(.5)
	skyRaycastTimer.set_one_shot(false)
	skyRaycastTimer.connect("timeout", self, "updateLightSize")
	add_child(skyRaycastTimer)
	
	# Set max size of the light
	originalLightSize = mapWidth / ($LightSource.texture.get_data().get_width()-lightTextureOffset)

	# Completed initialization
	initialized = true

# Called every timer execution to update vision
func updateLightSize():
	# Change vision based on distance to the closest player
	var node_group = get_tree().get_nodes_in_group("PlayerMainPawns")
	var nearestDistanceFromPlayer = mapDiag
	while node_group.size() > 0:
		var node = node_group.pop_back()
		if !node.get_parent().get_node("TeleportManager").teleporting and node != get_parent():
			var newPos = node.position.distance_to(get_parent().position)
			if newPos < nearestDistanceFromPlayer:
				nearestDistanceFromPlayer = newPos
	# Light size is a cotangent relationship
	if nearestDistanceFromPlayer < mapDiag:
		var calculatedLightSize = (lightModifier * (1/(tan((nearestDistanceFromPlayer/mapDiag)+(lightModifier/10))))) + lightModifier
		newLightSize = clamp(calculatedLightSize, lightMin, lightMax)
	else:
		newLightSize = originalLightSize

# Executed every physics frame
func _physics_process(_delta : float):
	if initialized:

		# Update raycast to sky
		$SkyRaycastCheck.force_raycast_update()

		# If the pawn's line of sight to the sky is blocked, limit vision
		if $SkyRaycastCheck.is_colliding() and !player_node.get_node("TeleportManager").teleporting:
			if !underground:
				if skyRaycastTimer.get_time_left() == 0:
					skyRaycastTimer.start()
				$LightSource.visible = true
				$CanvasModulate.visible = true
				underground = true
				currentLightSize = originalLightSize
				newLightSize = originalLightSize
				$LightSource.texture_scale = originalLightSize
		# If line of sight to the sky is not blocked, remove vision limit
		else:
			if underground:
				if skyRaycastTimer.get_time_left() > 0:
					skyRaycastTimer.stop()
				$LightSource.visible = false
				$CanvasModulate.visible = false
				underground = false
				get_node("LightCollisionArea/LightCollisionShape").shape.radius = (originalLightSize * ($LightSource.texture.get_size().x-(lightTextureOffset-60)))/2

	# Interpolate vision to what it should be instead of instantly snapping to final size
	if underground and currentLightSize != newLightSize:
		currentLightSize = lerp(currentLightSize, newLightSize, 0.01)
		$LightSource.texture_scale = currentLightSize
		get_node("LightCollisionArea/LightCollisionShape").shape.radius = (currentLightSize * ($LightSource.texture.get_size().x-(lightTextureOffset-60)))/2

# Execute when an entity enters vision
func _on_LightCollisionArea_body_entered(body):
	if body != get_parent():
		overlapping_nodes.append(body)

# Execute when an entity leaves vision
func _on_LightCollisionArea_body_exited(body):
	overlapping_nodes.erase(body)
