tool
extends RichTextEffect
class_name RichTextGhost

##### This custom bbcode text effect fades chat out after a specific period of time
# Syntax: [ghost freq=5.0 span=10.0][/ghost]

# Define the tag name.
var bbcode = "ghost"

func _process_custom_fx(char_fx):
	var threshold = char_fx.env.get("thres", 5.0)
	var fadetime = char_fx.env.get("fadetime", 1.0)
	var time = char_fx.env.get("time")
	if time != null:
		var remainingTime = time+(threshold*1000) - OS.get_ticks_msec()
		if remainingTime > (fadetime * 1000):
			char_fx.color.a = 1
		elif remainingTime <= (fadetime * 1000) and remainingTime > 0:
			char_fx.color.a = remainingTime / (fadetime * 1000)
		else:
			char_fx.color.a = 0
	return true
