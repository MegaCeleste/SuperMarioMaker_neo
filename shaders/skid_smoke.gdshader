// SPDX-License-Identifier: AGPL-3.0-or-later
shader_type canvas_item;
render_mode unshaded;

uniform float age = 0.0;
uniform float body_size = 0.18;
uniform float direction = 1.0;
varying vec2 local_point;

float circle(vec2 p, vec2 center, float radius) {
	return length(p - center) - radius;
}

void vertex() {
	local_point = VERTEX;
}

void fragment() {
	vec2 p = vec2(local_point.x * direction, local_point.y);
	vec2 body = p / max(body_size, 0.0001);
	// Joined filled lobes, rather than the old hollow eight-pixel smoke frame.
	float cloud = min(circle(body, vec2(-1.3, -1.9), 1.65), circle(body, vec2(0.5, -2.1), 2.25));
	cloud = min(cloud, circle(body, vec2(2.0, -1.25), 1.4));
	cloud = min(cloud, circle(body, vec2(-0.2, -0.75), 0.9)) * body_size;
	// A small trailing puff separates while the main mass contracts.
	float split = smoothstep(0.07, 0.105, age) * (1.0 - smoothstep(0.13, 0.25, age));
	if (split > 0.01) {
		float drift = clamp((age - 0.07) / 0.18, 0.0, 1.0);
		cloud = min(cloud, circle(p, vec2(3.8 + 1.4 * drift, -1.1 - 0.5 * drift), 0.65 * split));
	}
	float edge = max(fwidth(cloud) * 0.55, 0.0001);
	float coverage = 1.0 - smoothstep(-edge, edge, cloud);
	COLOR = vec4(vec3(1.0), age >= 0.30 ? 0.0 : coverage);
}
