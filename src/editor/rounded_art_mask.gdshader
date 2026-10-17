shader_type canvas_item;

uniform float radius = 0.23;
uniform float feather = 0.003;

void fragment() {
    vec2 p = abs(UV - vec2(0.5)) - vec2(0.5 - radius);
    float d = length(max(p, vec2(0.0)))
        + min(max(p.x, p.y), 0.0)
        - radius;

	vec4 tex = texture(TEXTURE, UV);
	tex.a *= 1.0 - smoothstep(0.0, feather, d);
	COLOR = tex;
}