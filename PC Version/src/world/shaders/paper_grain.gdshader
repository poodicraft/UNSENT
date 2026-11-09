shader_type canvas_item;
// Gives vector-drawn puppets the same paper fibre texture as the painted
// backgrounds. Grain is sampled in the node's local space so it moves with
// the character instead of swimming across the screen.

uniform sampler2D grain : repeat_enable, filter_linear;
uniform float amount = 0.10;
uniform float scale = 150.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float g = texture(grain, local_pos / scale).r;
	COLOR.rgb *= 1.0 + (g - 0.5) * amount * 2.0;
}
