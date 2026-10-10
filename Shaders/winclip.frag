#version 440
// Window capture with Hyprland-style rounding + border, analytic (no mask FBO).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;  // px, includes border
    float radius;   // outer radius
    float border;   // px
    float power;    // corner superellipse exponent, Hyprland rounding_power
    vec4 borderColor;
};
layout(binding = 1) uniform sampler2D src;

float sdBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    if (q.x > 0.0 && q.y > 0.0) {
        float m = max(q.x, q.y);
        vec2 u = q / m;
        return m * pow(pow(u.x, power) + pow(u.y, power), 1.0 / power) - r;
    }
    return max(q.x, q.y) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize - itemSize * 0.5;
    float d = sdBox(p, itemSize * 0.5, radius);
    // AA width in item px, so edges stay smooth at fractional scales
    float aa = max(fwidth(d), 1e-3);
    float outer = clamp(0.5 - d / aa, 0.0, 1.0);
    float inner = clamp(0.5 - (d + border) / aa, 0.0, 1.0);
    // window texture maps to the area inside the border
    vec2 uv = (qt_TexCoord0 * itemSize - border) / (itemSize - 2.0 * border);
    vec4 win = texture(src, uv);
    fragColor = mix(borderColor * outer, win, inner) * qt_Opacity;
}
