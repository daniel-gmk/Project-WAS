extends Sprite

# Track the max length and height of the map for boundary checks
var maxLength
var maxHeight

# Generates the entire terrain and collision from seed, unique and dynamic shape
# TODO: Save colors as variables. For now:
# Color 1 1 1 1 is white
# Color 1 1 0 1 is yellow
# Color 0 0 1 1 is blue
# Color 0 0 0 1 is black
func loadTerrain(terrainSeed, ip):	
	
	# Loads the image into file
	var image = texture.get_data()
	# Locks image so pixels can be retrieved and modified
	image.lock()
	
	# Save data into main dictionary.
	# Array fg is foreground, has all pixels touching the base that are blue
	# Array bg is background, all pixels that are black
	var points = {'fg': [], 'bg': []}
	for w in image.get_width():
		for h in image.get_height():
			# Grab all pixels (blue) that are touching the base (white)
			if image.get_pixel(w, h) == Color(0,0,1,1):
				if (image.get_pixel(w+1, h) == Color(1,1,1,1) or image.get_pixel(w-1, h) == Color(1,1,1,1) or image.get_pixel(w, h+1) == Color(1,1,1,1) or image.get_pixel(w, h-1) == Color(1,1,1,1)): # Blue
					points['fg'].push_back([w, h])

	# Load two perlin noises
	
	# First perlin noise is for the blue contour
	var noise = OpenSimplexNoise.new()
	noise.seed = terrainSeed
	noise.octaves = 1
	noise.period = 64.0
	noise.persistence = 0.8
	# Second perlin noise is for the background as second layer
	var noise2 = OpenSimplexNoise.new()
	noise2.seed = terrainSeed
	noise2.octaves = 1
	noise2.period = 24.0
	noise2.persistence = 0.4

	# Threshold is at what level of perlin value will be used for the terrain. Higher means more will be allowed.
	var threshold = 40
	
	# Parse through image 
	for w in image.get_width():
		for h in image.get_height():

			# Grab perlin noises based on threshold for blue contour
			var value = abs(noise.get_noise_2d(w, h))
			value = max(0, (threshold - value * 256) * 8)

			# Grab perlin noises based on threshold for black background
			var value2
			if image.get_pixel(w, h) == Color(0,0,0,1): # Black
				value2 = abs(noise2.get_noise_2d(w, h))
				value2 = max(0, (25 - value2 * 256) * 8)
				value = (value + value2) / 2.0
			
			# Do not apply changes to base (white)
			if image.get_pixel(w, h) != Color(1,1,1,1): # White
				# Change blue contour to black
				image.set_pixel(w, h, Color(0,0,0,1)) # Black
				# Apply yellow marker color to perlin patterns
				if value > threshold:
					image.set_pixel(w, h, Color(1,1,0,1)) # Yellow

	# This component grows the base terrain (white) to the areas touching it that are surrounded by perlin patterns.
	var pt
	var x
	var y
	var x1
	var spanAbove
	var spanBelow
	
	while points['fg'].size() > 0:
		pt = points['fg'].pop_back()
		x = pt[0]
		y = pt[1]
		x1 = x
		while (x1 >= 0) and (image.get_pixel(x1, y) == Color(0,0,0,1)):
			x1 -= 1
		x1 += 1
		spanAbove = 0
		spanBelow = 0
		while (x1 < image.get_width()) and (image.get_pixel(x1, y) == Color(0,0,0,1)):
			image.set_pixel(x1, y, Color(1,1,1,1))
			if !spanAbove and y > 0 and (image.get_pixel(x1, y-1) == Color(0,0,0,1)):
				points['fg'].push_back([x1, y-1])
				spanAbove = 1
			elif spanAbove and y > 0 and (image.get_pixel(x1, y-1) != Color(0,0,0,1)):
				spanAbove = 0
			if !spanBelow and y < (image.get_height()-1) and (image.get_pixel(x1, y+1) == Color(0,0,0,1)):
				points['fg'].push_back([x1, y+1])
				spanBelow = 1
			elif spanBelow and y < (image.get_height()-1) and (image.get_pixel(x1, y+1) != Color(0,0,0,1)):
				spanBelow = 0
			x1 += 1
		
	# This component removes perlin yellow placeholder colors
	for w in image.get_width():
		for h in image.get_height():
			# Grab pixels that are the contour
			if image.get_pixel(w, h) == Color(1,1,0,1):
				image.set_pixel(w, h, Color(0,0,0,1))
	
	# This functionality goes 10 passes and adds a layer of pixels to all the new core terrain to smooth it out.
	# It is the worst abomination of code ive ever written, poor optimization but I need to find a better way to smooth terrain, such as dilation
	for l in range(0,10,1):
		for w in image.get_width():
			for h in image.get_height():
				# Grab pixels that touch the new white but are borders
				if image.get_pixel(w, h) == Color(1,1,1,1):
					if w < (image.get_width()-1) and w > 0 and h < (image.get_height()-1) and h > 0:
						if image.get_pixel(w+1, h) == Color(0,0,0,1) or image.get_pixel(w-1, h) == Color(0,0,0,1) or image.get_pixel(w, h+1) == Color(0,0,0,1) or image.get_pixel(w, h-1) == Color(0,0,0,1):
							points['bg'].push_back([w, h, 0])
		var bt
		var z
		var zlimit = 2
		var spanLeft
		var spanRight
		
		while points['bg'].size() > 0:
			bt = points['bg'].pop_back()
			x = bt[0]
			y = bt[1]
			z = bt[2]
			spanAbove = 0
			spanBelow = 0
			spanLeft = 0
			spanRight = 0
			if z < zlimit:
				image.set_pixel(x, y, Color(1,1,1,1))
				if !spanAbove and y > 0 and (image.get_pixel(x, y-1) == Color(0,0,0,1)):
					points['bg'].push_back([x, y-1, z+1])
					spanAbove = 1
				elif spanAbove and y > 0 and (image.get_pixel(x, y-1) != Color(0,0,0,1)):
					spanAbove = 0
				if !spanBelow and y < (image.get_height()-1) and (image.get_pixel(x, y+1) == Color(0,0,0,1)):
					points['bg'].push_back([x, y+1, z+1])
					spanBelow = 1
				elif spanBelow and y < (image.get_height()-1) and (image.get_pixel(x, y+1) != Color(0,0,0,1)):
					spanBelow = 0
				if !spanLeft and x > 0 and (image.get_pixel(x-1, y) == Color(0,0,0,1)):
					points['bg'].push_back([x-1, y, z+1])
					spanLeft = 1
				elif spanLeft and x > 0 and (image.get_pixel(x-1, y) != Color(0,0,0,1)):
					spanLeft = 0
				if !spanRight and x < (image.get_width()-1) and (image.get_pixel(x+1, y) == Color(0,0,0,1)):
					points['bg'].push_back([x+1, y, z+1])
					spanRight = 1
				elif spanRight and x < (image.get_width()-1) and (image.get_pixel(x+1, y) != Color(0,0,0,1)):
					spanRight = 0

	# Removes black background and makes it transparent
	for w in image.get_width():
		for h in image.get_height():
			if image.get_pixel(w, h) == Color(0,0,0,1): # Black
				image.set_pixel(w, h, Color(0,0,0,0))
				
	# Unlocks image so size can be adjusted
	image.unlock()
	# Change size to set pixels
	image.resize(2000, 1500, 0)
	#image.resize(5000, 3750, 0)

	maxLength = position.x + image.get_width()
	maxHeight = position.y + image.get_height()

	# Converts image to texture and has sprite use the new texture
	var newtexture = ImageTexture.new()
	newtexture.create_from_image(image)
	self.set_texture(newtexture)

	# Generate destructible node so terrain collision and destruction can be applied
	var destructible_scene = load("res://Destructible.tscn")
	var destructible       = destructible_scene.instance()
	call_deferred("add_child", destructible)
	
	# After everything is loaded and done, client can reconnect to server
	if !get_tree().is_network_server():
		var network = get_node("/root/Network")
		network.rejoin_server_after_terrain(ip)
