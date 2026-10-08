#version 440
// Liquid-glass style surface: squircle slab with a convex squircle bevel,
// Snell refraction (IOR ~1.5) through the bevel, light blur, vibrancy,
// Fresnel rim and dual specular highlights.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;    // px
    vec2 itemPos;     // px, position on screen
    vec2 itemSpan;    // px, size on screen (differs from itemSize while scaled)
    vec2 screenSize;  // px
    float radius;     // corner radius
    float bevel;      // width of curved glass edge
    float strength;   // glass thickness, scales refraction, px
    float ior;        // index of refraction
    float dispersion; // chromatic split, 0..1
    float blur;       // blur radius, px
    float skew;       // pull toward the center along the rim, 0 = off
    float noise;      // grain amount
    float vibrancy;   // saturation boost
    vec4 tint;        // rgb + mix amount
    vec4 body;        // x, y, w, h of the main slab in item px
    vec4 neck;        // capsule merged into the slab (liquid bridge), w <= 0 = none
    float goo;        // smooth-min blend radius between body and neck, px
    float maxLuma;    // luminance cap keeping white content readable
};
layout(binding = 1) uniform sampler2D wall;

// rounded box, circular corners (matches Rectangle radius for concentric nesting)
float sdSquircle(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sdBody(vec2 p) {
    vec2 h = body.zw * 0.5;
    return sdSquircle(p - body.xy - h, h, min(radius, min(h.x, h.y)));
}

// polynomial smooth min: melts two shapes together like liquid
float smin(float a, float b, float k) {
    if (k <= 0.0) return min(a, b);
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float shape(vec2 p) {
    float d = sdBody(p);
    if (neck.z <= 0.0) return d;
    vec2 h = neck.zw * 0.5;
    return smin(d, sdSquircle(p - neck.xy - h, h, h.x), goo);
}

// clamp so edge samples never smear past the screen border
vec2 wallUv(vec2 px) { return clamp(px, vec2(0.5), screenSize - 0.5) / screenSize; }

// smooth blur: read a mip level matching the radius, then average a small
// ring of taps at that level to hide the mip box-filter blockiness
vec3 sampleBlur(vec2 px) {
    if (blur <= 0.5) return texture(wall, wallUv(px)).rgb;
    float lod = log2(blur);
    vec3 c = textureLod(wall, wallUv(px), lod).rgb * 2.0;
    for (int i = 0; i < 8; i++) {
        float a = float(i) * 0.785398;
        c += textureLod(wall, wallUv(px + vec2(cos(a), sin(a)) * blur * 0.6), lod).rgb;
    }
    return c / 10.0;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    float d = shape(p);
    float alpha = clamp(0.5 - d, 0.0, 1.0);
    if (alpha <= 0.0) { fragColor = vec4(0.0); return; }

    // outward edge direction from SDF gradient
    vec2 e = vec2(0.5, 0.0);
    vec2 g = normalize(vec2(shape(p + e.xy) - shape(p - e.xy),
                            shape(p + e.yx) - shape(p - e.yx)) + 1e-5);

    // Edge refraction, ported from liquid-glass-studio (iyinchao): within
    // `bevel` px of the rim the incidence angle grows as asin(x^2), Snell
    // gives the transmitted angle, and tan(thetaI - thetaT) sets how far
    // the ray is bent. Rays bend inward, toward the slab's centre.
    float depth = -d;
    float xr = 1.0 - depth / bevel;
    float thetaI = asin(clamp(xr * xr, 0.0, 1.0));
    float thetaT = asin(clamp(sin(thetaI) / ior, -1.0, 1.0));
    float edge = depth < bevel ? tan(thetaI - thetaT) : 0.0;
    vec2 shift = -g * edge * strength;
    // rounded-lens bow: vertical lines bend like "(" on the left half and ")"
    // on the right ("/" at the top, "|" mid-height, "\" at the bottom)
    // bow from the pixel's own position (smooth); it is added to the rim
    // refraction, so the reflection bends with the interior lines
    // bow is measured on the body slab
    vec2 half_ = body.zw * 0.5;
    vec2 pb = p - body.xy - half_;
    vec2 c = clamp(pb / half_, -1.0, 1.0);
    // only on the side ends: the outer 10% of the width
    float fade = body.z * 0.1;
    // ramps as t^7: barely there inside, sharply stronger right at the edge
    float t = clamp((abs(pb.x) - (half_.x - fade)) / fade, 0.0, 1.0);
    float ends = sign(pb.x) * pow(t, 7.0);
    // bends outward at the ends. Scaled by the fade width so the squeeze
    // stays ~1 - skew * 0.15 at any size.
    shift.x += ends * c.y * c.y * skew * fade * 0.1;

    vec2 px = itemPos + qt_TexCoord0 * itemSpan;
    vec3 col = vec3(sampleBlur(px + shift * (1.0 + dispersion)).r,
                    sampleBlur(px + shift).g,
                    sampleBlur(px + shift * (1.0 - dispersion)).b);

    // vibrancy: push saturation, lift slightly
    float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(vec3(lum), col, 1.0 + vibrancy) * 1.04 + 0.02;
    col = mix(col, tint.rgb, tint.a);
    // keep white content readable over bright backdrops: cap luminance
    float l2 = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col *= min(1.0, maxLuma / max(l2, 1e-3));

    // Fresnel: a ~6px band hugging the rim, lifted toward white
    float fres = clamp(pow(1.2 - depth * 0.09, 5.0), 0.0, 1.0);
    col = mix(col, vec3(1.0), fres * 0.045);
    // iOS 27: thin darkened edge just inside the rim for separation
    float rimDark = smoothstep(0.0, 1.5, depth) * (1.0 - smoothstep(1.5, 5.0, depth));
    col *= 1.0 - rimDark * 0.35;
    // glare: two lobes on opposite diagonals (doubled normal angle), key at
    // bottom-left, the far lobe at top-right dimmer
    float ang = atan(-g.y, g.x); // y-up angle of the rim normal
    bool far = g.x > 0.0 && g.y < 0.0;
    float glare = (0.5 + 0.5 * sin(2.0 * ang)) * 1.35 * (far ? 0.85 : 1.0); // iOS 27: brighter speculars
    glare = clamp(pow(glare, 1.1), 0.0, 1.0) * fres;
    col = mix(col, min(col * 1.6 + 0.5, vec3(1.0)), glare * 0.32);

    // thin white border on the outermost ~1px
    float border = 1.0 - smoothstep(0.5, 1.5, depth);
    col = mix(col, vec3(1.0), border * 0.25);

    col += (hash(px) - 0.5) * noise;
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * alpha * qt_Opacity;
}
