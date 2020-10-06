shader_type canvas_item;
uniform float outline_width = 2.0;
uniform vec4 outline_color: hint_color;

uniform sampler2D destruction_mask : hint_black;

uniform sampler2D mask_texture;

void fragment() {
	
	vec4 original_colour = texture(TEXTURE, UV).rgba;
	vec4 destruction_map_colour = texture(destruction_mask, UV).rgba;
	vec4 ground_colour = texture(mask_texture, UV);
	
	vec4 mix_color = vec4(mix(original_colour.rgb, ground_colour.rgb, original_colour.a), original_colour.a * destruction_map_colour.a);

	//vec4 col = texture(TEXTURE, UV);
	vec2 ps = TEXTURE_PIXEL_SIZE * outline_width;
	float a;
	float maxa = mix_color.a;
	float mina = mix_color.a;

	for(float x = -1.0; x <= 1.0; x+=0.05) {
		float y = 1.0 - (x*x);
		if(vec2(x,y) == vec2(0.0)) {
			continue; // ignore the center of kernel
		}
		a = texture(TEXTURE, UV + vec2(x,y)*ps).a * destruction_map_colour.a;
		maxa = max(a, maxa); 
		mina = min(a, mina);
	}
	for(float x = -1.0; x <= 1.0; x+=0.05) {
		float y = -1.0 + (x*x);
		if(vec2(x,y) == vec2(0.0)) {
			continue; // ignore the center of kernel
		}
		a = texture(TEXTURE, UV + vec2(x,y)*ps).a * destruction_map_colour.a;
		maxa = max(a, maxa); 
		mina = min(a, mina);
	}
	COLOR = mix(mix_color, outline_color, maxa-mina * mix_color.a);
}