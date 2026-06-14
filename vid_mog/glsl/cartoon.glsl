//!HOOK MAIN
//!BIND HOOKED
//!DESC Cyberpunk 2D Cartoon Cel Shader

// Helper to calculate pixel luminance for edge detection boundaries
float get_luma(vec3 rgb) {
    return dot(rgb, vec3(0.299, 0.587, 0.114));
}

vec4 hook() {
    vec2 uv = HOOKED_pos;
    vec4 raw_color = HOOKED_tex(uv);
    
    // 1. Get the physical coordinate offset size of exactly 1 pixel
    vec2 texel = HOOKED_pt; 
    
    // 2. Sample 4-point cross neighboring pixels to check for contrast shifts
    float top    = get_luma(HOOKED_tex(uv + vec2(0.0,  texel.y)).rgb);
    float bottom = get_luma(HOOKED_tex(uv + vec2(0.0, -texel.y)).rgb);
    float left   = get_luma(HOOKED_tex(uv + vec2(-texel.x, 0.0)).rgb);
    float right  = get_luma(HOOKED_tex(uv + vec2( texel.x, 0.0)).rgb);
    
    // Calculate geometric gradient delta
    float edge_intensity = abs(top - bottom) + abs(left - right);
    
    // 3. COLOR POSTERIZATION: Group smooth gradients into flat color tiers
    vec3 flat_color = raw_color.rgb;
    float color_steps = 5.0; // Higher = closer to real life, Lower = flatter cartoon style
    flat_color = floor(flat_color * color_steps) / color_steps;
    
    // 4. INK OUTLINE MIX: If a sharp contrast shift is found, draw a black line
    float edge_threshold = 0.08; // Adjust lower to catch finer lines, higher to clear noise
    if (edge_intensity > edge_threshold) {
        return vec4(0.0, 0.0, 0.0, 1.0); // Pure black ink stroke
    }
    
    return vec4(flat_color, raw_color.a);
}