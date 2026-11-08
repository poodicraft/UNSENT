shader_type canvas_item;
// Screen-space sky: gradient, sun glow, twinkling stars and drifting clouds.
// Every colour is a uniform so moods (dusk / storm / dawn) can tween between.

uniform vec4 top_color : source_color = vec4(0.11, 0.12, 0.27, 1.0);
uniform vec4 mid_color : source_color = vec4(0.33, 0.27, 0.49, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.94, 0.63, 0.48, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.84, 0.63, 1.0);
uniform vec4 cloud_color : source_color = vec4(0.77, 0.54, 0.63, 1.0);
uniform float horizon = 0.6;       // screen-space y of the horizon (0 = top)
uniform float sun_offset = 0.02;   // sun centre relative to the horizon (+ = below)
uniform float sun_x = 0.72;
uniform float stars = 1.0;
uniform float clouds = 0.5;
uniform float scroll = 0.0;        // camera position across the scene, 0..1
uniform float aspect = 0.5625;     // screen width / height
uniform float flash = 0.0;         // lightning
uniform sampler2D cloud_tex : repeat_enable, filter_linear;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	float y = uv.y;
	float h = horizon;
	vec3 col = mix(top_color.rgb, mid_color.rgb, smoothstep(0.0, h * 0.8, y));
	col = mix(col, horizon_color.rgb, smoothstep(h * 0.5, h, y));

	// Sun glow and disk
	vec2 sun = vec2(sun_x - scroll * 0.06, h + sun_offset);
	vec2 d = (uv - sun) * vec2(aspect, 1.0);
	float dist = length(d);
	float above = 1.0 - smoothstep(h - 0.01, h + 0.03, y);
	float glow = exp(-dist * 4.2) * 0.75 + exp(-dist * 16.0) * 0.55;
	col += glow_color.rgb * glow * above;
	float disk = (1.0 - smoothstep(0.026, 0.031, dist)) * (1.0 - step(h, y));
	col = mix(col, vec3(1.0, 0.97, 0.88), disk);

	// Stars
	vec2 sp = (uv + vec2(scroll * 0.04, 0.0)) * vec2(64.0 * aspect / 0.5625, 112.0);
	vec2 cell = floor(sp);
	vec2 f = fract(sp) - 0.5;
	float r = hash(cell);
	vec2 jitter = (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.55;
	float twinkle = 0.55 + 0.45 * sin(TIME * (0.7 + r * 2.4) + r * 60.0);
	float star = step(0.978, r) * (1.0 - smoothstep(0.03, 0.13, length(f + jitter))) * twinkle;
	star *= (1.0 - smoothstep(h * 0.2, h * 0.8, y)) * stars;
	col += vec3(1.0, 0.95, 0.86) * star * 1.2;

	// Clouds, lit from below by the horizon glow
	vec2 cuv = vec2(uv.x * 1.25 + TIME * 0.0035 + scroll * 0.10, y * 2.1);
	float c1 = texture(cloud_tex, cuv).r;
	float c2 = texture(cloud_tex, cuv * 0.47 + vec2(0.31, 0.13) - vec2(TIME * 0.0018, 0.0)).r;
	float cl = smoothstep(0.50, 0.86, c1 * 0.62 + c2 * 0.62) * clouds;
	cl *= smoothstep(0.02, h * 0.45, y) * (1.0 - smoothstep(h * 0.78, h + 0.01, y));
	vec3 ccol = mix(cloud_color.rgb, glow_color.rgb, smoothstep(h * 0.45, h, y) * 0.55);
	col = mix(col, ccol, cl * 0.8);

	col += vec3(0.75, 0.8, 1.0) * flash;
	COLOR = vec4(col, 1.0);
}
