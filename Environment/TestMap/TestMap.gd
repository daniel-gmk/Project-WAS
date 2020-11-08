extends Sprite

##### This node handles terrain generation for the initial test map and minimap

### Map Variables
# Track the max length and height of the map for boundary checks
var maxLength = 6000
var maxHeight = 4500
# Track the arrays used for processing the map in a background thread and prevent "not responding"
var _chunk_threads := Array()

### GUI Element Variables
# Tracks whether a GUI for loading screen is used
var gui = false
# Tracks the camera node used for viewing the map and load screen
var cameraNode
# Tracks the base GUI node for the loading screen
var controlNode
# Tracks the loading bar
var progressBarNode
# Tracks text under the loading bar stating the progress
var progressBarTextNode
# Tracks the minimap node to render the map to it
var minimapNode
# Tracks the size ratio between the minimap and the screen
var minimapRatio
# Tracks the size/dimensions of the minimap
var minimapSize = Vector2(240, 180)

# Closes open threads when exited from the scene
func _exit_tree():
	for thread in _chunk_threads:
		thread.wait_to_finish()

# Starts the generation process in another thread and signals clients back to server as loading map
# TODO: Save colors as variables. For now:
# Color 1 1 1 1 is white
# Color 1 1 0 1 is yellow
# Color 0 0 1 1 is blue
# Color 0 0 0 1 is black
func loadTerrain(terrainSeed, ip):
	minimapNode = get_node("/root/environment/MiniMap")
	
	# Set loading screen to be used
	if !get_tree().is_network_server() or get_node("/root/Network").hostingMode == 1:
		gui = true
	
	# Generate loading screen GUI
	if gui:
		cameraNode = get_node("/root/environment/Camera")
		cameraNode.position = Vector2(maxLength/2, maxHeight/2)
		cameraNode.zoom = Vector2(6,6)
		controlNode = cameraNode.get_node("CanvasLayer/Control")
		controlNode.visible = true
		progressBarNode = controlNode.get_node("ProgressBar")
		progressBarTextNode = controlNode.get_node("Label")

	# Start background thread for terrain generation
	var thread := Thread.new()
	var error = thread.start(self, "loadThread", [terrainSeed])
	if error != OK:
		print("Error creating destruction thread: ", error)
	_chunk_threads.push_back(thread)

	# After everything is loaded and done, client can reconnect to server
	var network = get_node("/root/Network")
	if !get_tree().is_network_server():
		network.terrain_loaded()
	else:
		if network.hostingMode == 1:
			get_node("/root/environment/Control").rect_position = Vector2(maxLength/8, maxHeight/8)

# Generates the entire terrain and collision from seed, unique and dynamic shape in a background thread
func loadThread(arguments : Array):

	# Update loading bar
	if gui:
		progressBarNode.value = 5
		progressBarTextNode.text = "Loading Image Data"

	# Loads the image into file
	var image = texture.get_data()
	set_texture(null)
	visible = true
	# Locks image so pixels can be retrieved and modified
	image.lock()

	# Update loading bar
	if gui:
		progressBarNode.value = 10
		progressBarTextNode.text = "Generating Random Terrain"
	
	# First perlin noise is for the blue contour
	var noise = OpenSimplexNoise.new()
	noise.seed = arguments[0]
	noise.octaves = 1
	noise.period = 60.0
	noise.persistence = .8

	var noise2 = OpenSimplexNoise.new()
	noise2.seed = arguments[0]
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
	
	# Update loading bar
	if gui:
		progressBarNode.value = 15
		progressBarTextNode.text = "Filling Random Terrain"

	# This component grows the base terrain (white) to the areas touching it that are surrounded by perlin patterns.
	var pt
	var x
	var y
	var x1
	var spanAbove
	var spanBelow

	# Uses scanline fill algorithm ported here
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
			# Grab pixels that are the contour of the base for the next component
			if image.get_pixel(w, h) == Color(0,0,0,1):
				image.set_pixel(w, h, Color(0,0,0,0))
			if image.get_pixel(w, h) == Color(1,1,0,1):
				points['bg'].push_back([w, h])
	
	# This component smooths out the resulting gaps/wedges within the terrain using a modified scanline fill, requires the map to have been filled already hence separate scanline fills
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
				if image.get_pixel(x1, y-1) == Color(0,0,0,0) or image.get_pixel(x1, y-1) == Color(0,0,0,0):
					topBottomFlag = true
			x1 -= 1
		if (x1 != -1 and image.get_pixel(x1, y) == Color(1,1,1,1)):
			whiteL = true
		x2 = max(0, x1)
		x1 = x
		while (x1 < image.get_width()) and (image.get_pixel(x1, y) == Color(1,1,0,1)):
			if y > 0 and y < image.get_height()-1 and !topBottomFlag:
				if image.get_pixel(x1, y-1) == Color(0,0,0,0) or image.get_pixel(x1, y-1) == Color(0,0,0,0):
					topBottomFlag = true
			x1 += 1
		if (x1 != image.get_width() and image.get_pixel(x1, y) == Color(1,1,1,1)):
			whiteR = true

		for u in range(x2, x1):
			if whiteL and whiteR and !topBottomFlag:
				image.set_pixel(u, y, Color(1,1,1,1))
			else:
				image.set_pixel(u, y, Color(0,0,0,0))

	# This components converts the resulting image to a bitmap to perform a hole-filling algorithm.
	# Existing holes and spots in the map cause rendering problems because Godot's bitmap-to-polygon 
	# function needed to add collision to this map is not properly working with holes
	var bm := BitMap.new()
	bm.create_from_image_alpha(image)
	var bm2 = bm.duplicate() as BitMap

	# First, we have two copies of the bitmap. The first copy fills everything outside the map, meaning the only thing left unfilled is holes inside the map
	# Then, we parse through the first copy and perform a fill on the inner parts on the second copy, essentially only filling the holes inside

	# Fill everything outside the first copy's map first
	for w in image.get_width():
		for h in image.get_height():
			if w == 0 or h == 0 or w == image.get_width()-1 or h == image.get_height()-1:
				if bm2.get_bit(Vector2(w, h)):
					continue
				bm2.set_bit(Vector2(w, h), true)
				var fillArray = []
				fillArray.push_back([w, h])
				var n
				while fillArray.size() > 0:
					n = fillArray.pop_front()
					if n[0]-1 > 0 and !bm2.get_bit(Vector2(n[0]-1, n[1])):
						bm2.set_bit(Vector2(n[0]-1, n[1]), true)
						fillArray.push_back([n[0]-1, n[1]])
					if n[0]+1 < image.get_width() and !bm2.get_bit(Vector2(n[0]+1, n[1])):
						bm2.set_bit(Vector2(n[0]+1, n[1]), true)
						fillArray.push_back([n[0]+1, n[1]])
					if n[1]-1 > 0 and !bm2.get_bit(Vector2(n[0], n[1]-1)):
						bm2.set_bit(Vector2(n[0], n[1]-1), true)
						fillArray.push_back([n[0], n[1]-1])
					if n[1]+1 < image.get_height() and !bm2.get_bit(Vector2(n[0], n[1]+1)):
						bm2.set_bit(Vector2(n[0], n[1]+1), true)
						fillArray.push_back([n[0], n[1]+1])

	# Parse through first copy for holes inside, but make changes to the second copy, and ultimately use the second copy
	for w in image.get_width():
		for h in image.get_height():
			if !bm2.get_bit(Vector2(w, h)):
				bm2.set_bit(Vector2(w, h), true)
				bm.set_bit(Vector2(w, h), true)
				var fillArray = []
				fillArray.push_back([w, h])
				var n
				while fillArray.size() > 0:
					n = fillArray.pop_front()
					if n[0]-1 > 0 and !bm2.get_bit(Vector2(n[0]-1, n[1])):
						bm2.set_bit(Vector2(n[0]-1, n[1]), true)
						bm.set_bit(Vector2(n[0]-1, n[1]), true)
						fillArray.push_back([n[0]-1, n[1]])
					if n[0]+1 < image.get_width() and !bm2.get_bit(Vector2(n[0]+1, n[1])):
						bm2.set_bit(Vector2(n[0]+1, n[1]), true)
						bm.set_bit(Vector2(n[0]+1, n[1]), true)
						fillArray.push_back([n[0]+1, n[1]])
					if n[1]-1 > 0 and !bm2.get_bit(Vector2(n[0], n[1]-1)):
						bm2.set_bit(Vector2(n[0], n[1]-1), true)
						bm.set_bit(Vector2(n[0], n[1]-1), true)
						fillArray.push_back([n[0], n[1]-1])
					if n[1]+1 < image.get_height() and !bm2.get_bit(Vector2(n[0], n[1]+1)):
						bm2.set_bit(Vector2(n[0], n[1]+1), true)
						bm.set_bit(Vector2(n[0], n[1]+1), true)
						fillArray.push_back([n[0], n[1]+1])

	# Replace the image data with the bit's data
	for w in image.get_width():
		for h in image.get_height():
			if bm.get_bit(Vector2(w, h)):
				image.set_pixel(w, h, Color(1,1,1,1))
			else:
				image.set_pixel(w, h, Color(1,1,1,0))

	# Unlocks image so size can be adjusted
	image.unlock()
	
	# Update loading bar
	if gui:
		progressBarNode.value = 20
		progressBarTextNode.text = "Expanding Terrain Size"

	# Create minimap as a copy of the new terrain
	var testImage = Image.new()
	testImage.copy_from(image)
	testImage.resize(minimapSize.x,minimapSize.y,0)
	minimapRatio = float(maxLength) / float(minimapSize.x)
	var testTexture = ImageTexture.new()
	testTexture.create_from_image(testImage)
	testTexture.set_flags(0)
	var dupsprite = minimapNode
	dupsprite.texture = testTexture
	dupsprite.material.set_shader_param("mask_texture", load("res://assets/minimap-background.png"))
	dupsprite.material.set_shader_param("outline_width", 0)
	var minimap_destructible_scene = load("res://Environment/Destructible-Minimap.tscn")
	var minimap_destructible       = minimap_destructible_scene.instance()
	dupsprite.call_deferred("add_child", minimap_destructible)
	
	# Upscale the map to max length, making it a little bit jagged (so we need to smooth it later)
	image.resize(maxLength,maxHeight,0)

	# Update loading bar
	if gui:
		progressBarNode.value = 25
		progressBarTextNode.text = "Adding Sky"

	# Add sky sprite to background
	var sky = get_parent().get_node("Sky")
	sky.visible = true
	sky.scale = Vector2(image.get_width()+2000 / sky.texture.get_data().get_width(), image.get_height()+2000 / sky.texture.get_data().get_height())
	sky.position = Vector2(-1000, -1000)

	# Update loading bar
	if gui:
		progressBarNode.value = 30
		progressBarTextNode.text = "Adding Chunks"

	# This component is an optimization of map rendering. Break the map into chunks and only attach destruction nodes to non-sky terrain

	# Tracks which sub-image we are at
	var count = 0
	# Tracks current location in overall image
	var placingWidth = 0
	var placingHeight = 0
	# Size of chunks
	var cropWidth = 300
	var cropHeight = 225
	# The rate in which each chunk update will update the loading bar
	var loadRate = float((maxLength * maxHeight) / (cropWidth * cropHeight))

	# Parse through rows
	while placingWidth < image.get_width():
		# Reset the height every time we get to a new width chunk (reset column every row)
		placingHeight = 0
		# Parse through columns
		while placingHeight < image.get_height():

			# Update loading bar each chunk is loaded
			if gui:
				var rateValue = float(progressBarNode.max_value - 30)
				progressBarNode.value = 30 + (rateValue * (count / loadRate))

			# Make children sprites of overall sprite with sub-images
			var childSprite = Sprite.new()
			childSprite.name = name + "-" + str(count)
			# Set the material so destruction works
			childSprite.material = ShaderMaterial.new()
			childSprite.material.shader = load("res://VisualEffects/parent_material.shader")
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
			var opaque = false

			# Checks if transparent so it can save time and not have to add destructible nodes if fully transparent
			for w in image2.get_width():
				for h in image2.get_height():
					# Grab pixels that are the contour
					if image2.get_pixel(w,h).a > 0:
						if transparent:
							transparent = false
							break

			# Checks if completely opaque so it can save time and not have to perform dilation/smoothing to a completely filled chunk
			if !transparent:
				opaque = true
				for w in image2.get_width():
					for h in image2.get_height():
						# Grab pixels that are the contour
						if image2.get_pixel(w,h).a < 1:
							if opaque:
								opaque = false
								break

			# For all other chunks perform smoothing
			if !transparent and !opaque:
				# Convert to bitmap for smoothing
				var bitmap := BitMap.new()
				bitmap.create_from_image_alpha(image2)
				var bitmapsize = bitmap.get_size()
				
				# Smooth terrain with built-in dilation function
				bitmap.grow_mask(10, Rect2(Vector2(), bitmap.get_size()))
				
				# Convert bitmap back to terrain
				for w in image2.get_width():
					for h in image2.get_height():
						if bitmap.get_bit(Vector2(w, h)):
							image2.set_pixel(w, h, Color(1,1,1,1))
						else:
							image2.set_pixel(w, h, Color(1,1,1,0))

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
				var destructible_scene = load("res://Environment/Destructible.tscn")
				var destructible       = destructible_scene.instance()
				childSprite.call_deferred("add_child", destructible)
			
			# Iterate
			count += 1
			placingHeight += cropHeight
		placingWidth += cropWidth

	# After completion, hide the loading screen
	if gui:
		controlNode.visible = false
