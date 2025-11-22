shader_type spatial;
render_mode cull_disabled; // Draw both sides of the blade

// --- COLOR SETTINGS ---
uniform vec3 color_top : source_color = vec3(0.4, 0.8, 0.2); // Bright Green
uniform vec3 color_bottom : source_color = vec3(0.1, 0.3, 0.0); // Dark Green

// --- WIND SETTINGS ---
uniform float wind_speed = 1.0;
uniform float wind_strength = 0.2;
uniform sampler2D wind_noise; // Assign a noise texture here for randomness

// --- INTERACTION ---
uniform vec3 player_position;
uniform float player_radius = 1.0;

void vertex() {
    // 1. Get World Position
    vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    
    // 2. Wind Calculation
    // We scroll the noise texture based on time and world position
    vec2 noise_uv = world_pos.xz * 0.1 + vec2(TIME * wind_speed * 0.1, 0.0);
    float noise_val = texture(wind_noise, noise_uv).r;
    
    // Convert noise (0.0 to 1.0) to a wave (-1.0 to 1.0)
    float wave = (noise_val * 2.0 - 1.0);
    
    // 3. Apply Displacement
    // UV.y is usually 0 at bottom and 1 at top for grass meshes.
    // We multiply by (1.0 - UV.y) assuming UV.y=0 is top. 
    // IF your mesh has UV.y=1 at top, use UV.y instead.
    // Let's assume standard: UV.y=1 is bottom (root), UV.y=0 is top (tip).
    float stiffness = (1.0 - UV.y); 
    
    VERTEX.x += wave * wind_strength * stiffness;
    VERTEX.z += wave * wind_strength * stiffness;
}

void fragment() {
    // 4. Color Gradient
    // Mix bottom and top colors based on UV height
    vec3 final_color = mix(color_top, color_bottom, UV.y);
    
    ALBEDO = final_color;
    ROUGHNESS = 0.8; // Not too shiny
    SPECULAR = 0.0;  // Stylized look usually has no specular
}