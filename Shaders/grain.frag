#version 440
// Static film grain inside a rounded rect, for matte surfaces.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float radius;
    float amount;
};

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    vec2 h = itemSize * 0.5;
    vec2 q = abs(p - h) - h + radius;
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    float inside = clamp(0.5 - d, 0.0, 1.0);
    // per pixel, light and dark specks around zero
    float n = hash(floor(p)) - 0.5;
    float a = abs(n) * 2.0 * amount * inside;
    fragColor = vec4(vec3(n > 0.0 ? 1.0 : 0.0) * a, a) * qt_Opacity;
}
