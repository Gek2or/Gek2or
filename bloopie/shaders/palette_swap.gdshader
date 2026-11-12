shader_type canvas_item;
// Recolours Bloopie's painted plush to the current theme. The art is painted
// in the `original` sky blue; every pixel whose hue sits in that blue family
// is moved by the hue / saturation / value difference between the source and
// the target base colour. Ink lines, teeth, blush and the eyes keep their look.

uniform vec4 source_base : source_color = vec4(0.62, 0.745, 0.933, 1.0);
uniform vec4 target_base : source_color = vec4(0.62, 0.745, 0.933, 1.0);
uniform vec4 target_shade : source_color = vec4(0.357, 0.557, 0.788, 1.0);
// Eyes in UV space (centre.xy, radius.zw): the irises stay blue in any theme.
uniform vec4 eye_left = vec4(0.405, 0.552, 0.108, 0.1);
uniform vec4 eye_right = vec4(0.728, 0.548, 0.098, 0.097);

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-6)), d / (q.x + 1e-6), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

float inside(vec2 uv, vec4 ellipse) {
	vec2 d = (uv - ellipse.xy) / ellipse.zw;
	return 1.0 - smoothstep(0.85, 1.0, dot(d, d));
}

void fragment() {
	vec4 color = COLOR;
	vec3 hsv = rgb_to_hsv(color.rgb);
	vec3 from = rgb_to_hsv(source_base.rgb);
	vec3 to = rgb_to_hsv(target_base.rgb);
	// How strongly this pixel belongs to the blue plush family.
	float hue_distance = abs(fract(hsv.x - from.x + 0.5) - 0.5);
	float plush = (1.0 - smoothstep(0.1, 0.16, hue_distance));
	plush *= smoothstep(0.03, 0.08, hsv.y) * smoothstep(0.34, 0.52, hsv.z);
	plush *= 1.0 - max(inside(UV, eye_left), inside(UV, eye_right));
	vec3 moved = hsv;
	moved.x = fract(hsv.x + to.x - from.x);
	moved.y = clamp(hsv.y * to.y / max(from.y, 0.01), 0.0, 1.0);
	moved.z = clamp(hsv.z * to.z / max(from.z, 0.01), 0.0, 1.0);
	// Deep shadows lean towards the theme's shade colour.
	vec3 swapped = mix(hsv_to_rgb(moved), target_shade.rgb, (1.0 - smoothstep(0.55, 0.9, hsv.z)) * 0.25);
	COLOR.rgb = mix(color.rgb, swapped, plush);
}
