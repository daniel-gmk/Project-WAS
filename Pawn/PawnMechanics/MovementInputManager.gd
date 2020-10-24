extends Node

# Integrated from a client side prediction / server reconcilliation demo
master var movement = Vector2()
var old_movement = Vector2()
var movement_counter = 0
var movement_list = []
var time = 0
var player_node

func _ready():
	player_node = get_parent().get_parent()

func _physics_process(delta):
	if is_network_master() and !get_parent().terminatePending:
		send_inputs(delta)
		check_ackowledged_inputs()

func _unhandled_input(event):
	# Client code
	if is_network_master() and !player_node.menuPressed and !player_node.get_node("TeleportManager").teleporting and player_node.currentActivePawn == get_parent():
		if(event.is_action_pressed("left")):
			movement.x = -1
		if(event.is_action_pressed("right")):
			movement.x = 1
		if(event.is_action_released("left")):
			if(movement.x == -1):
				movement.x = 0
		if(event.is_action_released("right")):
			if(movement.x == 1):
				movement.x = 0
		
		if movement != old_movement:
			old_movement = movement

puppet func update_input_on_server(id,movement):
	# Check if the input was processed 
	if movement_counter != id:
		movement_counter = id
		self.movement = movement

# remove last input acknowledged and every older input
func check_ackowledged_inputs():
	while movement_list.size() > 0 && movement_list[0][0] <= get_parent().ack:
		movement_list.pop_front()
		
func send_inputs(delta):
	movement_counter += 1
	movement_list.push_back([movement_counter, delta, movement])
	rpc_unreliable_id(1,"update_input_on_server",movement_counter, movement)
