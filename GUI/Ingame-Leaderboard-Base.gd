extends MarginContainer

##### Handles leaderboard menu's overall component, loading, management (when pressing tab)

# Tracks whether node is initialized/started
var initialized = false

# Tracks whether the node is active (in view or not)
var active = false

# Path and node to container that holds each player's score element
export var mainScoreElementsPath : NodePath
var mainScoreElements

# Keeps track of elements in play, if a player is not on the list an element will be created
var elementList = {}
# Keeps track of the actual element nodes in play, might merge with elementList later
var elementArray = []

# Called when the node enters the scene tree for the first time.
func initialize():
	mainScoreElements = get_node(mainScoreElementsPath)
	initialized = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if initialized:
		updateList()

func updateList():
	if initialized:
	# Tracks all players and whether players loaded in need to load a score element
		var player_group = get_tree().get_nodes_in_group("Player")
		for player in player_group:
			if !elementList.has(player.clientName):
				var leaderboardElementScene = load("res://GUI/Ingame-Leaderboard-Element.tscn")
				var leaderboardElementInstance = leaderboardElementScene.instance()
				leaderboardElementInstance.name = player.clientName
				mainScoreElements.add_child(leaderboardElementInstance)
				rect_position.y -= (leaderboardElementInstance.rect_size.y/2)
				elementList[player.clientName] = player
				leaderboardElementInstance.initialize(player)

# Sorts the elements for players by score with a quicksort algorithm
func sortElements():
	elementArray = mainScoreElements.get_children()
	quickSort(elementArray, 0, elementArray.size()-1)
	var i = 0
	var oldLayout = mainScoreElements.get_children()
	for child in elementArray:
		if child != oldLayout[i]:
			mainScoreElements.move_child(child, i)
		i += 1

# Helper quicksort implementation to sort
func quickSort(elementArr, low, high):
	if low < high:
		var pi = partition(elementArr, low, high)
		quickSort(elementArr, low, pi-1)
		quickSort(elementArr, pi + 1, high)

# Helper quicksort partition function to sort
func partition(elementArr, low, high):
	var pivot = int(elementArr[high].playerScore.text)
	
	var i = low - 1
	
	for j in range(low, high):
		if int(elementArr[j].playerScore.text) > pivot:
			i += 1
			var temp = elementArr[i]
			elementArr[i] = elementArr[j]
			elementArr[j] = temp
	var temp = elementArr[i+1]
	elementArr[i+1] = elementArr[high]
	elementArr[high] = temp
	return i + 1
