#version 440
// App icon styles. mode: 0 default, 1 dark, 2 clear, 3 tinted.
// Dark and tinted work like iOS: split the icon into its background plate and
// the glyph on it. The plate color is read from a ring just inside the icon's
// edge, at the same angle as the pixel, so two-tone and gradient plates work;
// pixels that differ from their local plate color are glyph.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float mode;
    vec4 tint;
};
layout(binding = 1) uniform sampler2D source;

const float RING = 0.37;

vec3 unpre(vec4 s) { return s.a > 0.0 ? s.rgb / s.a : vec3(0.0); }
float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

vec4 ringAt(float ang) {
    return textureLod(source, vec2(0.5) + vec2(cos(ang), sin(ang)) * RING, 2.5);
}

void main() {
    vec4 s = texture(source, qt_TexCoord0);
    if (s.a <= 0.0) { fragColor = vec4(0.0); return; }
    vec3 c = unpre(s);
    float l = luma(c);
    float a = s.a;

    if (mode > 0.5 && mode < 1.5 || mode > 2.5) {
        // how much of the ring is solid: low = free-form icon with no plate
        float solid = 0.0;
        for (int i = 0; i < 12; i++) solid += step(0.9, ringAt(float(i) * 0.523599).a);
        bool hasPlate = solid >= 10.0;

        vec2 d = qt_TexCoord0 - 0.5;
        vec4 r = ringAt(atan(d.y, d.x));
        vec3 bg = unpre(r);
        // glyph mask; free-form icons count as all glyph
        float fg = hasPlate && r.a > 0.9 ? smoothstep(0.1, 0.28, distance(c, bg)) : 1.0;
        // the plate's rim highlight is not glyph
        if (hasPlate) fg *= 1.0 - smoothstep(0.4, 0.43, max(abs(d.x), abs(d.y)));

        if (mode < 1.5) {
            // dark: charcoal plate; glyph keeps its colors, but a glyph darker
            // than a colorful plate (black on green) takes the plate's hue instead
            vec3 plate = vec3(0.12, 0.12, 0.13) + bg * 0.04;
            vec3 vivid = bg / max(max(bg.r, max(bg.g, bg.b)), 0.01) * 0.92;
            float sat = max(bg.r, max(bg.g, bg.b)) - min(bg.r, min(bg.g, bg.b));
            vec3 glyph = hasPlate && sat > 0.3 && l < luma(bg) ? mix(vivid, vec3(1.0), 0.1) : c;
            c = mix(plate, glyph, fg);
        } else {
            // tinted: charcoal plate, glyph shaded in the tint by its lightness
            vec3 plate = vec3(0.1) + tint.rgb * 0.05;
            // shade by contrast with the plate, so dark glyphs still read bright
            vec3 glyph = tint.rgb * mix(0.6, 1.05, clamp(abs(l - luma(bg)) * 2.0, 0.0, 1.0));
            c = hasPlate ? mix(plate, glyph, fg) : tint.rgb * mix(0.35, 1.05, l);
        }
    } else if (mode > 1.5) {
        // clear: frosted monochrome
        c = vec3(mix(0.55, 1.0, l));
        a *= mix(0.45, 0.9, l);
    }
    fragColor = vec4(c * a, a) * qt_Opacity;
}
