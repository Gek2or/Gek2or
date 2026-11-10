shader_type canvas_item;
// Recolours Bloopie's plush layers. The art is always painted in the `original`
// sky-blue ramp (shade -> base -> white); this shader finds where a pixel sits
// on that ramp and re-reads it from the target theme's ramp. Ink outlines, the
// golden rim light, stars and the leaf are off the ramp and stay untouched.

uniform vec4 source_base : source_color = vec4(0.541, 0.780, 0.969, 1.0);
uniform vec4 source_shade : source_color = vec4(0.357, 0.557, 0.788, 1.0);
uniform vec4 target_base : source_color = vec4(0.541, 0.780, 0.969, 1.0);
uniform vec4 target_shade : source_color = vec4(0.357, 0.557, 0.788, 1.0);
uniform float tolerance : hint_range(0.0, 0.5) = 0.07;

float project(vec3 point, vec3 from, vec3 to, out float distance_to_segment) {
	vec3 axis = to - from;
	float t = clamp(dot(point - from, axis) / max(dot(axis, axis), 0.00001), 0.0, 1.0);
	distance_to_segment = distance(point, from + axis * t);
	return t;
}

void fragment() {
	vec3 color = COLOR.rgb;
	float dark_distance;
	float light_distance;
	float dark_t = project(color, source_shade.rgb, source_base.rgb, dark_distance);
	float light_t = project(color, source_base.rgb, vec3(1.0), light_distance);
	vec3 dark_swap = mix(target_shade.rgb, target_base.rgb, dark_t);
	vec3 light_swap = mix(target_base.rgb, vec3(1.0), light_t);
	bool use_dark = dark_distance <= light_distance;
	float nearest = use_dark ? dark_distance : light_distance;
	vec3 swapped = use_dark ? dark_swap : light_swap;
	COLOR.rgb = mix(swapped, color, smoothstep(tolerance, tolerance * 1.6, nearest));
}
