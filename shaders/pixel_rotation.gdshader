// SPDX-License-Identifier: AGPL-3.0-or-later
shader_type canvas_item;

// Keep texel interiors sharp; only blend the screen-pixel footprint at a
// rotated texel boundary. No screen texture or previous frame is sampled.
varying vec4 tint;
varying float oblique;

void vertex() {
	tint = COLOR;
	vec2 axis = normalize((CANVAS_MATRIX * MODEL_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xy);
	oblique = step(0.0001, abs(axis.x * axis.y));
}

vec4 premultiply(vec4 color) {
	return vec4(color.rgb * color.a, color.a);
}

void fragment() {
	vec2 texel = UV / TEXTURE_PIXEL_SIZE - 0.5;
	vec2 footprint = clamp(fwidth(texel), vec2(0.0001), vec2(1.0));
	if (oblique < 0.5) {
		// Cardinal angles retain the existing nearest sampling, including
		// fractional camera scales and source origins on half pixels.
		COLOR = texture(TEXTURE, UV) * tint;
	} else {
		vec2 base = floor(texel);
		vec2 weight = clamp((fract(texel) - 0.5) / footprint + 0.5, vec2(0.0), vec2(1.0));
		vec2 uv00 = (base + 0.5) * TEXTURE_PIXEL_SIZE;
		vec4 a = premultiply(texture(TEXTURE, uv00));
		vec4 b = premultiply(texture(TEXTURE, uv00 + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)));
		vec4 c = premultiply(texture(TEXTURE, uv00 + vec2(0.0, TEXTURE_PIXEL_SIZE.y)));
		vec4 d = premultiply(texture(TEXTURE, uv00 + TEXTURE_PIXEL_SIZE));
		vec4 filtered = mix(mix(a, b, weight.x), mix(c, d, weight.x), weight.y);
		// Transparent PNG texels can contain black RGB. Interpolate in
		// premultiplied space, then restore straight alpha for blend_mix.
		COLOR = vec4(filtered.rgb / max(filtered.a, 0.00001), filtered.a) * tint;
	}
}
