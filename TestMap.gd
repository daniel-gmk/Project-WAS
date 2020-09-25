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
	
	# First perlin noise is for the blue contour
	var noise = OpenSimplexNoise.new()
	noise.seed = terrainSeed
	noise.octaves = 1
	noise.period = 60.0
	noise.persistence = .8

	var noise2 = OpenSimplexNoise.new()
	noise2.seed = terrainSeed
	noise2.octaves = 1
	noise2.period = 30.0
	noise2.persistence = .8

	# Threshold is at what level of perlin value will be used for the terrain. Less means more will be allowed.
	var threshold = 20
	
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

			# Grab perlin noises based on threshold for blue contour
			var value = abs(noise.get_noise_2d(w, h))
			value = max(0, (threshold - value * 256) * 8)
			
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
				image.set_pixel(u, y, Color(1,1,1,1))
			else:
				image.set_pixel(u, y, Color(0,0,0,0))

	# Unlocks image so size can be adjusted
	image.unlock()

	image.resize(6000,4500,0)
	var sky = get_parent().get_node("Sky")
	sky.scale = Vector2(image.get_width() / sky.texture.get_data().get_width(), image.get_height() / sky.texture.get_data().get_height())
	maxLength = position.x + image.get_width()
	maxHeight = position.y + image.get_height()

	# Variables used for below optimization function

	# Tracks which sub-image we are at
	var count = 0
	# Tracks current location in overall image
	var placingWidth = 0
	var placingHeight = 0
	# Size of chunks
	var cropWidth = 500
	var cropHeight = 375
	
	# Optimization of map rendering. Break the map into chunks and only attach destruction nodes to non-sky terrain
	while placingWidth < image.get_width():
		# Reset the height every time we get to a new width chunk (reset column every row)
		placingHeight = 0
		while placingHeight < image.get_height():
			# Make children sprites of overall sprite with sub-images
			var childSprite = Sprite.new()
			childSprite.name = name + "-" + str(count)
			# Set the material so destruction works
			childSprite.material = ShaderMaterial.new()
			childSprite.material.shader = load("res://parent_material.shader")
			childSprite.material.set_shader_param("mask_texture", load("res://assets/test-background.png"))
			# Set position and remove center so it is placed in the right location
			childSprite.centered = false
			childSprite.position = Vector2(placingWidth, placingHeight)
			# Add the sprite as a child to the main sprite (main sprite will be cleared at the end so we dont have redundant images)
			add_child(childSprite)
			# Now need to create the image to put in the texture that the sprite used. Hierarchy goes: image -> texture -> sub-image sprite -> main image sprite
			var image2 = Image.new()
			# Grab image from the main image, then crop
			image2.create_from_data(image.get_width(), image.get_height(), false, 5, image.get_data())
			# Define the rectangle to crop the overall image to, make it 2 pixels larger to fill potential >1px gaps
			var rect = Rect2(Vector2(placingWidth-2,placingHeight-2), Vector2(cropWidth+4,cropHeight+4))
			# Crop image to the rectangle
			image2 = image2.get_rect(rect)
			# Lock image to do pixels check to track if transparent
			image2.lock()
			# Track whether the sub-image is fully transparent or not
			var transparent = true
			var bitmap := BitMap.new()
			bitmap.create_from_image_alpha(image2)
			bitmap.grow_mask(5, Rect2(Vector2(), bitmap.get_size()))
			
			var bitmapsize = bitmap.get_size()
			# Checks if transparent so it can save time and not have to add destructible nodes if fully transparent
			for w in image2.get_width():
				for h in image2.get_height():
					# Grab pixels that are the contour
					if bitmap.get_bit(Vector2(w,h)):
						image2.set_pixel(w, h, Color(1,1,1,1))
						if transparent:
							transparent = false
					else:
						image2.set_pixel(w, h, Color(0,0,0,0))
						
			image2.unlock()
			# Remove mipmaps so there arent weird aliasing/filter/mipmap lines between sub-images, especially when zooming
			image2.clear_mipmaps()
	
			# Create texture for image to go in
			var newtexture2 = ImageTexture.new()
			newtexture2.create_from_image(image2)
			# Remove aliasing/filter/mipmap flags to remove weird lines between sub-images, especially when zooming
			newtexture2.set_flags(0)
			newtexture2.set_storage(0)
			# Add texture to sprite
			childSprite.set_texture(newtexture2)
			# Remove aliasing/filter/mipmap flags to remove weird lines between sub-images, especially when zooming
			childSprite.set_region_filter_clip(true)
			
			# Add destructible nodes to non-transparent sub-images
			# Generate destructible node so terrain collision and destruction can be applied
			if !transparent:
				var destructible_scene = load("res://Destructible.tscn")
				var destructible       = destructible_scene.instance()
				childSprite.call_deferred("add_child", destructible)

			count += 1

			placingHeight += cropHeight
		placingWidth += cropWidth

	self.set_texture(null)

	# After everything is loaded and done, client can reconnect to server
	if !get_tree().is_network_server():
		var network = get_node("/root/Network")
		network.rejoin_server_after_terrain(ip)
