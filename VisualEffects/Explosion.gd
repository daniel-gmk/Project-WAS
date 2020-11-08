extends Node2D

##### This node is a component of projectile, purely visual and creates explosion effect

func _ready():
	# Play explosion sprite
	$AnimatedSprite.play()


func _on_AnimatedSprite_animation_finished():
	# Destroy self when finished playing
	queue_free()
