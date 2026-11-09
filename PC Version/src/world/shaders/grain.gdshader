shader_type canvas_item;
// Animated film/paper grain: lightens and darkens alternately, no screen reads.

uniform sampler2D noise : repeat_enable, filter_linear;
uniform float amount = 0.05;
uniform float aspect = 0.5625;

void fragment() {
	float t = floor(TIME * 12.0);
	vec2 off = vec2(fract(sin(t * 12.9898) * 43758.5453), fract(sin(t * 78.233) * 43758.5453));
	float n = texture(noise, UV * vec2(2.4, 2.4 / aspect) + off).r - 0.5;
	COLOR = vec4(vec3(step(0.0, n)), abs(n) * amount * 2.0);
}
