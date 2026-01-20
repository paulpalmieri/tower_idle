// Horizontal Gaussian blur shader
// 9-tap separable blur kernel

extern vec2 direction; // (1/width, 0) for horizontal blur

// Pre-computed 9-tap Gaussian weights (sigma ~= 2.0)
const float weights[5] = float[5](
    0.227027,  // center
    0.1945946, // offset 1
    0.1216216, // offset 2
    0.054054,  // offset 3
    0.016216   // offset 4
);

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    vec4 result = Texel(tex, texture_coords) * weights[0];

    for (int i = 1; i < 5; i++) {
        vec2 offset = direction * float(i);
        result += Texel(tex, texture_coords + offset) * weights[i];
        result += Texel(tex, texture_coords - offset) * weights[i];
    }

    return result * color;
}
