shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_disabled;
uniform sampler2D grain : repeat_enable, filter_linear_mipmap;
varying vec3 local_dir;
void vertex() {
	local_dir = normalize(VERTEX);
}
void fragment() {
	vec3 p = normalize(local_dir);
	vec2 a = vec2(p.x - 0.5 * p.y, p.z + p.y * 0.7);
	vec2 b = vec2(p.z + p.x * 0.64, p.y - p.x * 0.46);
	float front = texture(grain, a * 1.24 + vec2(0.0009 * TIME, 0.0)).r;
	float curls = texture(grain, b * 3.4 + vec2(front * 0.38, -TIME * 0.0017)).r;
	float mist = smoothstep(0.53, 0.74, 0.64 * front + 0.36 * curls);
	ALBEDO = mix(vec3(0.66, 0.75, 0.82), vec3(1.0, 0.98, 0.93), curls);
	ALPHA = mist * 0.72;
	ROUGHNESS = 1.0;
}
