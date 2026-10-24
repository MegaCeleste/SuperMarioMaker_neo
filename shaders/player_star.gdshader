shader_type canvas_item;
render_mode unshaded;

uniform vec4 star_color : source_color = vec4(1.0, 1.0, 0.282353, 1.0);
uniform float flash_alpha = 1.0;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	// Source draws a solid-color silhouette over the original pose. Combine
	// those colors in one draw so motion/growth never creates a second Mario.
	COLOR = tint * vec4(mix(art.rgb, star_color.rgb, clamp(flash_alpha, 0.0, 1.0)), art.a);
}
