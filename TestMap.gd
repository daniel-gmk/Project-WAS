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
	noise.period = 150.0
	noise.persistence = .8

	# Threshold is at what level of perlin value will be used for the terrain. Higher means more will be allowed.
	var threshold = 30
	
	# Parse through image 
	for w in image.get_width():
		for h in image.get_height():

			# Grab perlin noises based on threshold for blue contour
			var value = abs(noise.get_noise_2d(w, h))
			value = max(0, (threshold - value * 256) * 8)
			
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
			if image.get_pixel(w, h) == Color(0,0,0,1):
				image.set_pixel(w, h, Color(0,0,0,0))
			if image.get_pixel(w, h) == Color(1,1,0,1):
				points['bg'].push_back([w, h])
	
	var x2
	while points['bg'].size() > 0:
		var whiteL = false
		var whiteR = false
		pt = points['bg'].pop_back()
		x = pt[0]
		y = pt[1]
		x1 = x
		var topBottomFlag = false
		while (x1 >= 0) and (image.get_pixel(x1, y) == Color(1,1,0,1)):
			if y > 0 and y < image.get_height()-1:
				if image.get_pixel(x1, y+1) == Color(0,0,0,0) or image.get_pixel(x1, y+1) == Color(0,0,0,0):
					topBottomFlag = true
			x1 -= 1
		if (x1 != -1 and image.get_pixel(x1, y) == Color(1,1,1,1)):
			whiteL = true
		x2 = max(0, x1)
		x1 = x
		while (x1 < image.get_width()) and (image.get_pixel(x1, y) == Color(1,1,0,1)):
			if y > 0 and y < image.get_height()-1 and !topBottomFlag:
				if image.get_pixel(x1, y+1) == Color(0,0,0,0) or image.get_pixel(x1, y+1) == Color(0,0,0,0):
					topBottomFlag = true
			x1 += 1
		if (x1 != image.get_width() and image.get_pixel(x1, y) == Color(1,1,1,1)):
			whiteR = true

		for u in range(x2, x1):
			if whiteL and whiteR and !topBottomFlag:
				image.set_pixel(u, y, Color(0,0,1,1))
			else:
				image.set_pixel(u, y, Color(0,0,0,0))

	for w in image.get_width():
		for h in image.get_height():
			if image.get_pixel(w, h) == Color(0,0,1,1):
				image.set_pixel(w, h, Color(1,1,1,1))

	# Unlocks image so size can be adjusted
	image.unlock()
	# Change size to set pixels
	#image.resize(8000, 6000, 0)

	maxLength = position.x + image.get_width()
	maxHeight = position.y + image.get_height()

	# Variables used for below optimization function
			
			# Add destructible nodes to non-transparent sub-images
			# Generate destructible node so terrain collision and destruction can be applied

	var newtexture2 = ImageTexture.new()
	newtexture2.create_from_image(image)
	# Add texture to sprite
	set_texture(newtexture2)

	#var destructible_scene = load("res://Destructible.tscn")
	#var destructible       = destructible_scene.instance()
	#call_deferred("add_child", destructible)
	
	# Remove main image texture
	#self.set_texture(null)
	
	# After everything is loaded and done, client can reconnect to server
	if !get_tree().is_network_server():
		var network = get_node("/root/Network")
		network.rejoin_server_after_terrain(ip)
