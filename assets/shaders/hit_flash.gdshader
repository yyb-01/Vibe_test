shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 flash_rgb = vec3(1.0);
	COLOR = vec4(mix(source.rgb, flash_rgb, flash_amount), source.a);
}
