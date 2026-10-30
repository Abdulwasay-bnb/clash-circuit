// Shared body of the textured anime cel shader (included by generated variants in vrm_rig.gd).
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 shade : source_color = vec4(0.62, 0.58, 0.78, 1.0);
uniform vec4 rim_color : source_color = vec4(0.75, 0.88, 1.0, 1.0);
uniform float rim_amount = 0.18;
uniform float flash = 0.0;
uniform float emission_strength = 0.0;
uniform float saturation = 1.0;   // per-fighter recolor: 0 = greyscale
uniform float brightness = 1.0;

void fragment() {
	vec4 c = texture(tex, UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(vec3(lum), c.rgb, saturation) * brightness;
	c *= albedo;
	ALBEDO = c.rgb;
	#ifdef USE_ALPHA
	ALPHA = c.a;
	#endif
	#ifdef USE_SCISSOR
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	#endif
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = c.rgb * emission_strength + rim_color.rgb * fr * rim_amount + vec3(flash);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, 0.05, ndl) * 0.75 + smoothstep(0.55, 0.6, ndl) * 0.25;
	lit *= mix(0.4, 1.0, ATTENUATION);
	DIFFUSE_LIGHT += ALBEDO * mix(shade.rgb, vec3(1.0), lit) * LIGHT_COLOR * 0.42;
}
