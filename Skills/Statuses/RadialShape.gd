extends CollisionShape2D

# Passed from the parent (RadialDamage), set the radius of the collision shape (circle)
func setSize(val):
	shape.set_radius(val)
