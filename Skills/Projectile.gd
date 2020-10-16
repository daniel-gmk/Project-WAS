extends RigidBody2D

### Root node for projectile, handling behavior when hitting entities

# Track size of terrain damage radius, allow it to be set
var explosion_radius
# Track scene type of explosion effect
export var explosion_scene : PackedScene
# Track radial damage scene to create aoe effect and have it handle/apply damage
var radialDamage = load("res://Skills/Statuses/RadialDamage.tscn")
var terrainDamage = load("res://Environment/TerrainDamage.tscn")
# Track damage dealt, this is passed from the caster/player
var damage
# Track if there is flat damage dealt as long as within range of explosion, or if there is falloff from the center.
# The center leading up to 40% the radius will consist of max damage, but from there it will fall off. The terrain
# damage will also only be 70% of the total size.
var damage_falloff
# Tracks whether to ignore damage and collision to the caster (useful for certain attacks)
var ignoreCaster
# Keeps track of who casted the spell for ignoreCaster
var casterID
# Tracks whether the projectile is local to the client or from the server
var server

var knockback_force
var knockback_dropoff

# Start a timer looping each second to destroy projectiles out of bounds
var inActionTimer = Timer.new()

# Execute when this node loads
func _ready():
	# Loop the timer each second
	inActionTimer.set_wait_time(1.0)
	# Make sure its not just a one time execution and loops infinitely
	inActionTimer.set_one_shot(false)
	# Perform inAction_loop function each execution
	inActionTimer.connect("timeout", self, "inAction_loop")
	# Instantiate and start the timer
	add_child(inActionTimer)
	inActionTimer.start()

# Checks if it is outside 500 pixels of the bounds of the map
func inAction_loop():
	if position.x >= get_parent().get_node("TestMap").maxLength + 200 or position.x <= -200 or position.y <= -200:
		removeinActionTimer()
		queue_free()

# Remove the timer before removing this projectile
func removeinActionTimer():
	if inActionTimer.get_time_left() > 0:
		inActionTimer.queue_free()

func _on_Projectile_body_entered(_body):
	# Only if this is the server's projectile
	if !server:
		removeinActionTimer()
		queue_free()
	else:
		var newRadius = explosion_radius
		# Hole left in terrain is relatively smaller than explosion itself if damage falloff is enabled
		if damage_falloff == true:
			newRadius = 0.7 * explosion_radius
		
		var td = terrainDamage.instance()
		td.position = position
		# Add the child with a deferred call approach to avoid collision/propogation errors
		get_parent().call_deferred("add_child", td)
		td.monitoring = true
		td.setSize(newRadius)
		td.call_deferred("setExplosion")
		
		# Summon a radial damage node, which will issue the damage.
		var rd = radialDamage.instance()
		# Set and pass variables from projectile to damage node
		rd.position = position
		rd.damage = damage
		rd.damage_falloff = damage_falloff
		rd.casterID = casterID
		rd.ignoreCaster = ignoreCaster
		rd.knockback_force = knockback_force
		rd.knockback_dropoff = knockback_dropoff
		# Add the child with a deferred call approach to avoid collision/propogation errors
		get_parent().call_deferred("add_child", rd)
		# Ensures that the radial damage node is detecting collision
		rd.monitoring = true
		# Setting size of the explosion so that overlapping nodes get detected
		rd.setSize(explosion_radius)
		# Calls in deferred fashion to avoid collision/propogation errors, initiates the scan to detect overlapping nodes and issue damage
		rd.call_deferred("setExplosion")
		
		# Show purely visual explosion to clients
		get_node("/root/").get_node("1").broadcastExplosionServer(position)
		
		# Self terminate after all this is over. Again, this is only for the server's projectile.
		# There is also a "fake" projectile sent for clients for user experience
		removeinActionTimer()
		queue_free()
