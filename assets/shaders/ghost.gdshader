shader_type canvas_item;

uniform vec4 ghost_color : source_color = vec4(0.35, 0.9, 1.0, 0.55);

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	COLOR = vec4(ghost_color.rgb, source.a * ghost_color.a * COLOR.a);
}
