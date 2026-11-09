shader_type canvas_item;
// Soft dark vignette to frame the diorama.

uniform float strength = 0.45;
uniform vec4 tint : source_color = vec4(0.03, 0.02, 0.08, 1.0);

void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.0, 1.12);
	float v = smoothstep(0.32, 0.92, length(d)) * strength;
	COLOR = vec4(tint.rgb, v);
}
