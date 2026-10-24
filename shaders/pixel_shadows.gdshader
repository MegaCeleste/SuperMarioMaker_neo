// SPDX-License-Identifier: AGPL-3.0-or-later
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D silhouette : hint_screen_texture, repeat_disable, filter_nearest;
uniform float opacity : hint_range(0.0, 1.0) = 0.33;

void fragment() {
	// CanvasGroup's transparent backbuffer contains only the mirrored art.
	// Apply opacity once to the union, so adjoining tiles never darken seams.
	COLOR = vec4(0.0, 0.0, 0.0, textureLod(silhouette, SCREEN_UV, 0.0).a * opacity);
}
