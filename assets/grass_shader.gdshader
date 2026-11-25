shader_type spatial;
render_mode cull_disabled;

uniform vec3 color : source_color;
uniform vec3 color2 : source_color;
uniform sampler2D noise;
uniform float noiseScale = 20.0;

// Wind parameters
uniform vec2 wind_direction = vec2(1.0, 0.5);
uniform float wind_speed = 2.0;
uniform float wind_strength = 0.15;

varying vec3 worldPos;

void vertex() {
	// Calculate base world position before applying movement
	worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Generate continuous wave pattern
	float wind_wave = sin(TIME * wind_speed + worldPos.x + worldPos.z);

	// Calculate displacement vector
	// The mask isolates movement to the tips of the mesh, keeping roots static
	float vertical_mask = UV.y;
	vec2 displacement = wind_direction * wind_wave * wind_strength * vertical_mask;

	// Apply vector directly to local vertex coordinates
	VERTEX.x += displacement.x;
	VERTEX.z += displacement.y;
}

void fragment() {
	vec3 noiseLevel = texture(noise, worldPos.xy / noiseScale).rgb;
	ALBEDO = mix(color, color2, UV.y) * mix(color, color2, noiseLevel.r);
	
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}