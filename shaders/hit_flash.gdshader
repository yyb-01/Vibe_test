shader_type canvas_item;

uniform bool active = false;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 previous_color = texture(TEXTURE, UV);
	if (active) {
		COLOR = vec4(flash_color.rgb, previous_color.a);
	} else {
		COLOR = previous_color;
	}
}