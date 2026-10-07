#version 440
// Progressive blur: strong at the top edge, fading to clear at the bottom.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;   // px
    vec2 itemPos;    // px, position on screen
    vec2 screenSize; // px
    float blur;      // blur radius at the top, px
    vec4 tint;       // rgb + mix amount at the top
};
layout(binding = 1) uniform sampler2D wall;

vec2 wallUv(vec2 px) { return clamp(px, vec2(0.5), screenSize - 0.5) / screenSize; }

void main() {
    vec2 px = itemPos + qt_TexCoord0 * itemSize;
    float t = 1.0 - qt_TexCoord0.y;  // 1 at top, 0 at bottom
    float r = max(blur * t, 1.0);
    float lod = log2(r);
    vec3 c = textureLod(wall, wallUv(px), lod).rgb * 2.0;
    for (int i = 0; i < 8; i++) {
        float a = float(i) * 0.785398;
        c += textureLod(wall, wallUv(px + vec2(cos(a), sin(a)) * r * 0.6), lod).rgb;
    }
    c = mix(c / 10.0, tint.rgb, tint.a * t);
    float alpha = smoothstep(0.0, 1.0, t);
    fragColor = vec4(c * alpha, alpha) * qt_Opacity;
}
