shader_type spatial;
render_mode specular_disabled;
uniform sampler2D grain : repeat_enable, filter_linear_mipmap;
uniform int season = 0;
varying vec3 pos;
varying float slope;

void vertex() {
	pos = VERTEX;
	slope = 1.0 - dot(normalize(VERTEX), NORMAL);
}

void fragment() {
	// Two oblique projections avoid a longitude seam and pole pinching.
	vec2 a = vec2(pos.x + 0.47 * pos.y, pos.z - 0.61 * pos.y);
	vec2 b = vec2(pos.y + 0.36 * pos.z, pos.x - 0.71 * pos.z);
	float patches = texture(grain, a * 3.4).r;
	float grit = texture(grain, b * 17.0 + patches * 0.09).r;
	float strata = texture(grain, vec2(b.x * 7.0, length(pos) * 110.0 + grit * 0.24)).r;
	float cliff = smoothstep(0.025, 0.21, slope);
	vec3 soil = COLOR.rgb;
	if (!OUTPUT_IS_SRGB) { soil = pow(soil, vec3(2.2)); }
	ALBEDO = soil * (0.68 + 0.45 * patches + 0.26 * grit)
		* mix(vec3(1.0), vec3(0.66, 0.61, 0.57) + 0.48 * strata, cliff);
	// A damp band and fine sand ridges follow elevation around each shoreline.
	float elevation = length(pos) - 1.0;
	float beach = (1.0 - smoothstep(0.002, 0.011, elevation)) * (1.0 - cliff);
	float damp = 1.0 - smoothstep(0.0005, 0.004 + patches * 0.0015, elevation);
	float sand = sin(elevation * 2800.0 + patches * 4.0) * 0.025;
	ALBEDO *= 1.0 + beach * (sand - 0.18 * damp);
	float cover = smoothstep(0.002, 0.018, elevation) * (1.0 - cliff);
	if (season == 1) ALBEDO *= mix(vec3(1.0), vec3(1.08, 1.03, 0.90), cover);
	if (season == 2) ALBEDO *= mix(vec3(1.0), vec3(1.32, 0.87, 0.68), cover);
	if (season == 3) ALBEDO = mix(ALBEDO, vec3(0.76, 0.84, 0.90), cover * smoothstep(0.22, 0.77, patches) * 0.7);
	ROUGHNESS = mix(0.94, 0.56, beach * damp);
}
