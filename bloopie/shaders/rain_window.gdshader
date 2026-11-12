shader_type canvas_item;
// Living rain over the painted window: two parallax layers of falling streaks
// and a faint twinkle of stars, drawn as a transparent overlay.

uniform float rain_intensity : hint_range(0.0, 1.0) = 0.8;
uniform float star_amount : hint_range(0.0, 1.0) = 0.0;
uniform float aspect = 1.2;

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

void fragment() {
	vec2 square = vec2(UV.x * aspect, UV.y);
	float rain = rain_layer(square, 30.0, 1.5) * 0.6 + rain_layer(square + 0.5, 54.0, 2.3) * 0.4;
	vec2 star_grid = square * 34.0;
	vec2 star_cell = floor(star_grid);
	float star_seed = hash(star_cell);
	float star = smoothstep(0.1, 0.0, length(fract(star_grid) - 0.5 - (vec2(hash(star_cell + 1.0), hash(star_cell + 2.0)) - 0.5) * 0.7));
	star *= step(0.9, star_seed) * (0.5 + 0.5 * sin(TIME * 1.6 + star_seed * 40.0));
	// Fade the overlay out towards its edges so it never shows a hard border.
	float edge = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x) * smoothstep(1.0, 0.8, UV.y);
	float alpha = clamp(rain * 0.5 * rain_intensity + star * star_amount * 0.7, 0.0, 1.0) * edge;
	COLOR = vec4(mix(vec3(0.8, 0.87, 1.0), vec3(1.0, 0.96, 0.84), step(0.001, star * star_amount)), alpha);
}
