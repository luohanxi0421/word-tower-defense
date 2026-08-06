shader_type canvas_item;

// AI-generated sprites come on a white background (no alpha channel).
// Knock out near-white pixels so only the monster shows.
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.r > 0.95 && c.g > 0.95 && c.b > 0.95) {
		c.a = 0.0;
	}
	COLOR = c;
}
