shader_type canvas_item;
// "The future changed" — a radial shimmer that distorts the whole screen.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float progress = 0.0;     // 0 → 1
uniform vec2 center = vec2(0.5, 0.5);
uniform float aspect = 0.5625;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = (uv - center) * vec2(aspect, 1.0);
	float dist = length(d);
	float radius = progress * 1.25;
	float ring = exp(-pow((dist - radius) * 14.0, 2.0)) * (1.0 - progress);
	vec2 dir = dist > 0.0001 ? d / dist : vec2(0.0);
	uv += dir * ring * 0.022 / vec2(aspect, 1.0);
	vec3 col = texture(screen_tex, uv).rgb;
	col += vec3(0.55, 0.75, 1.0) * ring * 0.35;
	float sat = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(sat) * vec3(0.85, 0.95, 1.1), ring * 0.4);
	COLOR = vec4(col, 1.0);
}
