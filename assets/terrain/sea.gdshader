shader_type spatial;
uniform vec4 shallow_color : source_color;
uniform vec4 deep_color : source_color;
varying float depth;
varying vec3 radial;

void vertex() {
	radial = normalize(VERTEX);
	depth = 1.0 - length(VERTEX);
	VERTEX = radial;
	NORMAL = radial;
}

void fragment() {
	vec3 p = normalize(radial);
	vec3 d1 = vec3(0.73, 0.29, 0.62);
	vec3 d2 = vec3(-0.38, 0.87, 0.30);
	float swell = dot(p, d1) * 96.0 + TIME * 1.45;
	float ripple = dot(p, d2) * 167.0 - TIME * 1.9 + 0.8 * sin(swell);
	vec3 gradient = 0.068 * cos(swell) * d1 + 0.048 * cos(ripple) * d2;
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(p - gradient + p * dot(gradient,p), 0.0)).xyz);
	float shelf = smoothstep(0.001, 0.036, depth);
	vec3 water = mix(shallow_color.rgb, deep_color.rgb * 0.78, shelf);
	float surf = 1.0 - smoothstep(0.0006, 0.0048, abs(depth - 0.0018 - 0.0013 * sin(swell)));
	surf *= smoothstep(-0.65, 0.8, sin(ripple * 0.53 + swell));
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 4.0);
	ALBEDO = mix(water, vec3(0.75,0.87,0.84), surf * 0.62 + fresnel * 0.16);
	ROUGHNESS = mix(0.22, 0.67, surf);
	SPECULAR = 0.72;
}
