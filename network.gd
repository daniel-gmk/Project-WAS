extends Node

### Network node component in charge of creating games, joining game, connection, disconnection

# Port used for the game
const DEFAULT_PORT = 31416
# Max player connections
const MAX_PEERS    = 10
# List of all players
var   players      = {}
# Keep track of local player network ID, this will be the name of the player node
var   player_name
# Track the seed for terrain generated to the server so the same terrain is used for clients
var terrainSeed
# Check if terrain is loaded and it is time to load in the player or not
var loadedTerrain = false
# Track the server IP for reconnection after terrain is loaded
var serverIp
# Keep track of the old ID when loading terrain so it can be deleted locally when reconnecting
var oldPlayerID
# Preload the scenes for placeholder player, server, and post terrain render player
var placeholderPlayerScene = preload("res://temporaryPlayer.tscn")
var server_scene = preload("res://Server.tscn")
var player_scene = preload("res://Client.tscn")

var host

# Link Godot networking functions to the local functions here
func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")

# Function for server when hosting
func start_server():
	# Name can be customizable, but for server will not be visible anyway
	player_name = 'Server'
	host    = NetworkedMultiplayerENet.new()
	# Atempt to create server
	var err = host.create_server(DEFAULT_PORT, MAX_PEERS)
	# Joins its own server when successfully created
	if (err!=OK):
		join_server('127.0.0.1')
		return
	# Establishes role as server
	get_tree().set_network_peer(host)
	# Initialize terrain seed, randomized
	randomize()
	terrainSeed = randi()
	# Locally load the terrain as server
	get_node("/root/environment/TestMap").loadTerrain(terrainSeed, "127.0.0.1")
	# Spawn invisible server node
	spawn_player(1, true)
	
# Function for clients when joining/connecting, establishing connection
func join_server(ip):
	# Name can be changed to steam name or custom name down the road
	player_name = 'Client'
	host    = NetworkedMultiplayerENet.new()
	# Track the IP used to connect when clicking connect button for reconnecting after terrain loaded
	serverIp = ip
	# Create client connection
	host.create_client(ip, DEFAULT_PORT)
	# Establish role as peer/client
	get_tree().set_network_peer(host)

# If server disconnects
func _server_disconnected():
	quit_game()	

# Remove self from network and clear list of players, add logic later to send clients back to main menu and terminate connections
func quit_game():
	get_tree().set_network_peer(null)
	players.clear()

# Function for when connected, but doesn't track if connected successfully so uses _connected_ok()
func _player_connected(id):
	pass
	
# Function for when server detects client has disconnected, unregister and delete client listing to other clients
func _player_disconnected(id):
	unregister_player(id)
	rpc("unregister_player", id)

# Removes player node and player lists if it exists
remote func unregister_player(id):
	if get_node("/root/").has_node(str(id)):
		get_node("/root/" + str(id)).queue_free()
	if players.has(id):
		players.erase(id)
	
# Function for when successfully connected
func _connected_ok():
	# If terrain is not loaded yet, receive seed int from server to load terrain and reconnect
	if !loadedTerrain:
		rpc_id(1, "server_send_terrain_seed", get_tree().get_network_unique_id())
	else:
		# Receive handshake from server, notifying it is connected and having server allow client to proceed registration
		rpc_id(1, "user_ready", get_tree().get_network_unique_id(), player_name, loadedTerrain)

# Server receives handshake from client, sends client back instructions on registration
remote func user_ready(id, player_name, loadedTerrain):
	if get_tree().is_network_server():
		rpc_id(id, "register_in_game", player_name, loadedTerrain)

# Client now locally calls registration process and RPC broadcasts to everyone (server and client) same process
remote func register_in_game(player_name, loadedTerrain):
	rpc("register_new_player", get_tree().get_network_unique_id(), player_name, loadedTerrain)
	register_new_player(get_tree().get_network_unique_id(), player_name, loadedTerrain)
	
# Register player data of all other connected entities and spawn their characters in to the new client
remote func register_new_player(id, name, loadedTerrain):
	# If server, register and spawn character node in the new client
	if get_tree().is_network_server():
		rpc_id(id, "register_new_player", 1, player_name, loadedTerrain)
		# Loop through other players and register/spawn their characters in to the new client
		for peer_id in players:
			rpc_id(id, "register_new_player", peer_id, players[peer_id], loadedTerrain)
		
	# Populate list of players, including new player
	players[id] = name
	# Spawn the character/nodes
	spawn_player(id, loadedTerrain)
	
# Spawn the node/character of the server or client
func spawn_player(id, loadedTerrain):
	# If server, create a server node
	if id == 1:
		var server = server_scene.instance()
		server.set_name(str(id))
		get_node("/root/").call_deferred("add_child", server)
	else:
		# If player and terrain is now loaded
		# Load the normal character node
		var player = player_scene.instance()
		player.set_name(str(id))
	
		# Set variables locally for the actual client's player
		if id == get_tree().get_network_unique_id():
			player.set_network_master(id)
			player.player_id = id
			player.control   = true
			
		# Instantiate the character
		get_node("/root/").call_deferred("add_child", player)

# Server sends terrain seed to client
remote func server_send_terrain_seed(id):
	if get_tree().is_network_server():
		rpc_id(id, "client_receive_terrain_seed", terrainSeed)
	host.disconnect_peer(id)

# Client receives terrain seed from server
remote func client_receive_terrain_seed(rpcSeed):
	terrainSeed = rpcSeed
	get_node("/root/").get_node("environment").get_node("TestMap").loadTerrain(terrainSeed, serverIp)

# Called from the Map after loading is complete, since client disconnected now we reconnect
func rejoin_server_after_terrain(ip):
	player_name = 'Client'
	host    = NetworkedMultiplayerENet.new()
	loadedTerrain = true
	host.create_client(ip, DEFAULT_PORT)
	get_tree().set_network_peer(host)

# Called when the server clicks "start" game in base control node
func start_game():
	if get_tree().is_network_server():
		# For all clients, instantiate their player and playerPhysicsBody nodes
		for peer_id in players:
			if peer_id != 1:
				rpc_id(peer_id, "startPlayerGameCharacterRPC", peer_id)
				startPlayerGameCharacter(peer_id)
	else:
		rpc_id(1, "start_game_server")

remote func start_game_server():
	if get_tree().is_network_server():
		start_game()

# Have the client tell other clients to instantiate their player/playerPhysicsBody nodes
# And then instantiate their player/playerPhysicsBody node locally
remote func startPlayerGameCharacterRPC(peer_id):
	get_node("/root/").get_node("environment").get_node("Camera").queue_free()
	rpc("startPlayerGameCharacterRPC2", peer_id)
	startPlayerGameCharacter(peer_id)

# This is for other clients when a different client tells it to instantiate their player/playerPhysicsBody nodes
remote func startPlayerGameCharacterRPC2(peer_id):
	if !get_tree().is_network_server():
		startPlayerGameCharacter(peer_id)

# Called by all clients to have their client node instantiate the player/playerPhysicsBody node
func startPlayerGameCharacter(peer_id):
	get_node("/root/").get_node(str(peer_id)).startGameCharacter()
	# Gives the authority of the input manager to the player
	get_node("/root/").get_node(str(peer_id)).get_node("player").get_node("playerPhysicsBody").get_node("InputManager").set_network_master(peer_id)
