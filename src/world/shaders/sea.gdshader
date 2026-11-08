shader_type canvas_item;
// World-space sea: colour fades from the horizon glow to the deep, with
// drifting light streaks that gather in the sun's column.

uniform vec4 deep_color : source_color = vec4(0.14, 0.17, 0.32, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.85, 0.58, 0.5, 1.0);
uniform vec4 glint_color : source_color = vec4(1.0, 0.8, 0.6, 1.0);
uniform float sun_x = 0.72;      // screen-space
uniform float glint = 1.0;
uniform float flash = 0.0;

varying vec2 world;

void vertex() {
	world = VERTEX;
}

void fragment() {
	float y = UV.y;
	vec3 col = mix(horizon_color.rgb * 0.92, deep_color.rgb, smoothstep(0.0, 0.42, y));
	float freq = mix(0.45, 0.16, y);
	float band = sin(world.y * freq + sin(world.x * 0.0045 + TIME * 0.25) * 2.2 - TIME * 1.05);
	float streak = smoothstep(0.80, 1.0, band);
	float lane = exp(-pow((SCREEN_UV.x - sun_x) * 3.2, 2.0));
	float sparkle = streak * (0.18 + lane * 0.82) * (1.0 - y * 0.55) * glint;
	col += glint_color.rgb * sparkle * 0.5;
	float fine = smoothstep(0.92, 1.0, sin(world.y * 1.3 + world.x * 0.013 - TIME * 0.8));
	col += vec3(0.05) * fine * (1.0 - y);
	col += vec3(0.6, 0.65, 0.8) * flash * (1.0 - y * 0.5);
	COLOR = vec4(col, 1.0);
}
