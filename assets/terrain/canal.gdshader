shader_type spatial;
render_mode cull_disabled;
uniform bool flowing = false;
void fragment() {
	float banks = smoothstep(0.30, 0.48, abs(UV.x - 0.5));
	float wave = 0.5 + 0.5 * sin(UV.y * 70.0 - TIME * 4.0);
	vec3 channel = flowing ? mix(vec3(0.06,0.28,0.32),vec3(0.16,0.46,0.48),wave) : vec3(0.18,0.12,0.07);
	ALBEDO = mix(channel, vec3(0.34,0.26,0.16), banks);
	ROUGHNESS = flowing ? 0.45 : 0.95;
}
