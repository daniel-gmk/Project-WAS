extends Node2D

var underground = false
var currentLightSize
var newLightSize
var originalLightSize
var skyRaycastTimer = Timer.new()
var mapWidth
var mapHeight
var mapDiag
export var lightModifier = .2
export var lightMin = .125
export var lightMax = 12
export var lightTextureOffset = 245
var casting = false
var overlapping_nodes = []

var player_node

# Called when the node enters the scene tree for the first time.
func _ready():
	player_node = get_parent().get_parent()
	if get_tree().is_network_server() or !player_node.control:
		queue_free()
	mapWidth = get_node(player_node.map_path).maxLength
	mapHeight = get_node(player_node.map_path).maxHeight
	mapDiag = sqrt((mapWidth * mapWidth) + (mapHeight * mapHeight))
	$SkyRaycastCheck.add_exception(get_parent())
	$SkyRaycastCheck.cast_to = Vector2(0,mapHeight)
	skyRaycastTimer.set_wait_time(.5)
	# Make sure its not just a one time execution and loops infinitely
	skyRaycastTimer.set_one_shot(false)
	# Perform inAction_loop function each execution
	skyRaycastTimer.connect("timeout", self, "updateLightSize")
	add_child(skyRaycastTimer)
	
	# Remove this later, testing max size of the light2D
	originalLightSize = mapWidth / ($LightSource.texture.get_data().get_width()-lightTextureOffset)

func updateLightSize():
	# Change newLightSize to a new value based on average distance from players (smaller if larger average distance)
	# Also change the mask cause its not centered and its kind of ugly
	var node_group = get_tree().get_nodes_in_group("PlayerMainPawns")
	var nearestDistanceFromPlayer = mapDiag
	while node_group.size() > 0:
		var node = node_group.pop_back()
		if !node.get_parent().get_node("TeleportManager").teleporting and node != get_parent():
			var newPos = node.position.distance_to(get_parent().position)
			if newPos < nearestDistanceFromPlayer:
				nearestDistanceFromPlayer = newPos
	if nearestDistanceFromPlayer < mapDiag:
		var calculatedLightSize = (lightModifier * (1/(tan((nearestDistanceFromPlayer/mapDiag)+(lightModifier/10))))) + lightModifier
		newLightSize = clamp(calculatedLightSize, lightMin, lightMax)
	else:
		newLightSize = originalLightSize

func _physics_process(_delta : float):
	$SkyRaycastCheck.force_raycast_update()
	if $SkyRaycastCheck.is_colliding() and !player_node.get_node("TeleportManager").teleporting:
		if !casting:
			if skyRaycastTimer.get_time_left() == 0:
				skyRaycastTimer.start()
			$LightSource.visible = true
			$CanvasModulate.visible = true
			underground = true
			currentLightSize = originalLightSize
			newLightSize = originalLightSize
			$LightSource.texture_scale = originalLightSize
			casting = true

	else:
		if casting:
			if skyRaycastTimer.get_time_left() > 0:
				skyRaycastTimer.stop()
			$LightSource.visible = false
			$CanvasModulate.visible = false
			underground = false
			casting = false
			get_node("LightCollisionArea/LightCollisionShape").shape.radius = (originalLightSize * ($LightSource.texture.get_size().x-lightTextureOffset))/2

	if underground and currentLightSize != newLightSize:
		currentLightSize = lerp(currentLightSize, newLightSize, 0.01)
		$LightSource.texture_scale = currentLightSize
		get_node("LightCollisionArea/LightCollisionShape").shape.radius = (currentLightSize * ($LightSource.texture.get_size().x-lightTextureOffset))/2

func _on_LightCollisionArea_body_entered(body):
	if body != get_parent():
		overlapping_nodes.append(body)

func _on_LightCollisionArea_body_exited(body):
	overlapping_nodes.erase(body)
