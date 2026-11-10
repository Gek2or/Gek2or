shader_type canvas_item;
// Window glass: twilight sky gradient, distant hills, warm bokeh city lights,
// stars and procedural rain streaks running down the pane.

uniform vec4 sky_top : source_color = vec4(0.20, 0.17, 0.42, 1.0);
uniform vec4 sky_bottom : source_color = vec4(0.72, 0.48, 0.66, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.72, 0.44, 1.0);
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.8;
uniform float star_amount : hint_range(0.0, 1.0) = 0.0;
uniform float aspect = 0.62;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rain_layer(vec2 uv, float columns, float speed) {
	vec2 grid = vec2(uv.x * columns, uv.y * columns * 0.16);
	float column = floor(grid.x);
	grid.y -= TIME * speed * (0.6 + hash(vec2(column, 1.0)) * 0.8) + hash(vec2(column, 7.0)) * 10.0;
	vec2 cell = vec2(column, floor(grid.y));
	vec2 f = fract(grid);
	float present = step(1.0 - rain_intensity * 0.6, hash(cell));
	float x = abs(f.x - 0.5 - (hash(cell + 3.0) - 0.5) * 0.5);
	float streak = smoothstep(0.07, 0.0, x) * smoothstep(0.0, 0.5, f.y) * smoothstep(1.0, 0.9, f.y);
	return streak * present;
}

float bokeh(vec2 uv, float cells, float seed) {
	vec2 grid = uv * cells;
	vec2 cell = floor(grid);
	vec2 f = fract(grid) - 0.5;
	float present = step(0.62, hash(cell + seed));
	vec2 offset = vec2(hash(cell + seed + 1.3), hash(cell + seed + 2.7)) - 0.5;
	float radius = 0.16 + 0.2 * hash(cell + seed + 4.1);
	float d = length(f - offset * 0.5);
	float flicker = 0.75 + 0.25 * sin(TIME * (0.6 + hash(cell) * 1.5) + hash(cell + 9.0) * 6.28);
	return smoothstep(radius, radius * 0.55, d) * present * flicker;
}

void fragment() {
	vec2 uv = UV;
	vec2 square = vec2(uv.x * aspect, uv.y);
	vec3 color = mix(sky_top.rgb, sky_bottom.rgb, smoothstep(0.05, 0.72, uv.y));
	color += glow_color.rgb * 0.22 * smoothstep(0.35, 0.72, uv.y) * (1.0 - smoothstep(0.72, 0.95, uv.y));

	// Stars in the upper sky.
	vec2 star_grid = square * 46.0;
	vec2 star_cell = floor(star_grid);
	float star_seed = hash(star_cell);
	float star = smoothstep(0.09, 0.0, length(fract(star_grid) - 0.5 - (vec2(hash(star_cell + 1.0), hash(star_cell + 2.0)) - 0.5) * 0.7));
	star *= step(0.86, star_seed) * (0.6 + 0.4 * sin(TIME * 1.5 + star_seed * 40.0));
	color += vec3(1.0, 0.95, 0.82) * star * star_amount * (1.0 - smoothstep(0.3, 0.62, uv.y));

	// Soft hills / tree line on the horizon.
	float ridge = 0.62 + 0.035 * sin(uv.x * 9.0 + 1.0) + 0.02 * sin(uv.x * 23.0) + 0.012 * sin(uv.x * 57.0 + 2.0);
	float hills = smoothstep(ridge - 0.004, ridge + 0.012, uv.y);
	vec3 hill_color = mix(sky_top.rgb, vec3(0.07, 0.07, 0.18), 0.62);
	color = mix(color, hill_color, hills);

	// Warm out-of-focus lights of the town below the ridge.
	float lights = bokeh(square, 9.0, 0.0) + 0.7 * bokeh(square + 0.37, 15.0, 5.0);
	color += glow_color.rgb * lights * 0.55 * smoothstep(ridge - 0.01, ridge + 0.08, uv.y);

	// Rain: two parallax layers of streaks plus a faint wet sheen.
	float rain = rain_layer(square, 34.0, 1.5) * 0.55 + rain_layer(square + 0.5, 62.0, 2.3) * 0.35;
	color += vec3(0.78, 0.85, 1.0) * rain * 0.6;
	color = mix(color, color * 0.92 + vec3(0.03, 0.03, 0.06), rain_intensity * 0.35);

	COLOR = vec4(color, 1.0);
}
